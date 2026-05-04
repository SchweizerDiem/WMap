import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:home_widget/home_widget.dart';

// Bibliotecas para gestão de fusos horários e localização de tempo
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Importação das páginas e gestores de estado da aplicação
import './pages/welcome.dart';
import './pages/login.dart';
import './pages/register.dart';
import './pages/settings.dart';
import './pages/profile.dart';
import './pages/friends.dart';
import './pages/gallery.dart';
import 'session_manager.dart';
import 'country_names.dart';
import './pages/trip_details_form.dart';

// --- FUNÇÕES UTILITÁRIAS GLOBAIS ---

// Padroniza os códigos de país para letras minúsculas (ex: 'PT')
String normalizeCountryCode(String code) {
  return code.toLowerCase();
}

// Constrói o widget da bandeira. Inclui uma correção específica para o Kosovo (XK)
// que muitas vezes não existe em pacotes padrão de bandeiras.
Widget buildFlag(String code, {double width = 40, double height = 24}) {
  final cleanCode = code.toUpperCase();
  if (cleanCode == 'XK') {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/Flag_of_Kosovo.svg.webp',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
  return SizedBox(
    width: width,
    height: height,
    child: country_flags.CountryFlag.fromCountryCode(cleanCode),
  );
}

void main() async {
  // Garante que os serviços nativos estão prontos antes de iniciar o Firebase/Plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a base de dados de fusos horários IANA
  tz.initializeTimeZones();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // Verifica se o utilizador marcou "lembrar-me" e se já existe uma sessão ativa
  final prefs = await SharedPreferences.getInstance();
  final bool rememberMe = prefs.getBool('remember_me') ?? false;
  final user = FirebaseAuth.instance.currentUser;

  Widget initialScreen;

  // Lógica de encaminhamento inicial (Home ou Welcome)
  if (rememberMe && user != null) {
    final session = SessionManager();
    await session.refreshUserData();
    initialScreen = const HomePage();
  } else {
    initialScreen = const WelcomePage();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WMap',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: initialScreen,
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/settings': (context) => const SettingsPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isUpdatingWidget =
      false; // Controla o overlay de carregamento do widget
  int currentPageIndex = 0; // Índice da barra de navegação inferior
  final TextEditingController _searchController = TextEditingController();
  // Controlador para gerir o zoom e posição do mapa
  final TransformationController _transformationController =
      TransformationController();
  // Chave para identificar o mapa e permitir tirar "print" dele
  final GlobalKey _mapKey = GlobalKey();
  Set<String> _nationalityCountries = <String>{};

  @override
  void initState() {
    super.initState();

    // Adiciona ouvintes para atualizar a UI quando as cores globais mudarem
    final session = SessionManager();
    session.visitedColorNotifier.addListener(_onColorChanged);
    session.plannedColorNotifier.addListener(_onColorChanged);
    session.nationalityColorNotifier.addListener(_onColorChanged);

    // Define o zoom inicial do mapa focado numa área específica
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _transformationController.value = Matrix4.identity()
            ..scale(4.0)
            ..translate(-150.0, -210.0, 0.0);
        });
      }
    });

    // Carrega dados do utilizador e verifica se precisa definir nacionalidade
    Future.delayed(Duration.zero, () async {
      await session.refreshUserData();
      final user = session.getCurrentUser();

      if (user != null) {
        setState(() {
          _nationalityCountries = user.nationalities.toSet();
        });
        if (user.nationalities.isEmpty && mounted) {
          _showNationalityPicker();
        }
        _updateWidgetMap();
      }
    });
  }

  @override
  void dispose() {
    // Limpeza de recursos para evitar fugas de memória
    final session = SessionManager();
    session.visitedColorNotifier.removeListener(_onColorChanged);
    session.plannedColorNotifier.removeListener(_onColorChanged);
    session.nationalityColorNotifier.removeListener(_onColorChanged);

    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onColorChanged() {
    if (mounted) setState(() {});
  }

  // --- LÓGICA DO WIDGET ---
  // Esta função tira uma "foto" do mapa atual e envia para o widget do Android
  Future<void> _updateWidgetMap() async {
    if (!mounted || currentPageIndex != 0 || _mapKey.currentContext == null)
      return;

    try {
      setState(() => _isUpdatingWidget = true);

      // Guarda posição original e faz reset ao zoom para capturar o mapa inteiro
      final originalMatrix = Matrix4.fromFloat64List(
        _transformationController.value.storage,
      );
      _transformationController.value = Matrix4.identity();

      await Future.delayed(const Duration(milliseconds: 500));

      // Converte o RenderBox do mapa numa imagem PNG
      final RenderRepaintBoundary? boundary =
          _mapKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/map_snapshot.png';
          await File(imagePath).writeAsBytes(byteData.buffer.asUint8List());

          // Guarda o caminho da imagem e o contador para o plugin home_widget
          await HomeWidget.saveWidgetData<String>('map_image_path', imagePath);
          final session = SessionManager();
          final visitedCount = session
              .getVisitedCountriesForCurrentUser()
              .length;
          await HomeWidget.saveWidgetData<String>(
            'visited_count_text',
            'Visited: $visitedCount/250',
          );

          // Força o Android a redesenhar o widget
          await HomeWidget.updateWidget(
            name: 'MapWidgetProvider',
            androidName: 'MapWidgetProvider',
          );
        }
      }

      // Restaura o zoom original do utilizador
      _transformationController.value = originalMatrix;
      setState(() => _isUpdatingWidget = false);
    } catch (e) {
      if (mounted) setState(() => _isUpdatingWidget = false);
      debugPrint("Erro Widget Update: $e");
    }
  }

  // --- LÓGICA DE TEMPO ROBUSTA (OFFLINE) ---
  // Obtém a hora atual de um país usando mapeamento IANA ou offset UTC
  String _getCountryTime(String countryCode, List<dynamic> timezones) {
    try {
      final Map<String, String> codeToLocation = {
        'PT': 'Europe/Lisbon',
        'ES': 'Europe/Madrid',
        'GB': 'Europe/London',
        'FR': 'Europe/Paris',
        'DE': 'Europe/Berlin',
        'IT': 'Europe/Rome',
        'BR': 'America/Sao_Paulo',
        'US': 'America/New_York',
        'JP': 'Asia/Tokyo',
        'CN': 'Asia/Shanghai',
        'RU': 'Europe/Moscow',
        'AO': 'Africa/Luanda',
        'CV': 'Atlantic/Cape_Verde',
        'CH': 'Europe/Zurich',
        'BE': 'Europe/Brussels',
        'NL': 'Europe/Amsterdam',
      };

      String? locationName = codeToLocation[countryCode.toUpperCase()];

      if (locationName != null) {
        final location = tz.getLocation(locationName);
        final now = tz.TZDateTime.now(location);
        return DateFormat('HH:mm').format(now);
      }

      // Fallback: se não estiver no mapa, calcula manualmente pelo offset (ex: UTC+02:00)
      if (timezones.isNotEmpty) {
        return _calculateTimeFromOffset(timezones[0].toString());
      }

      return "--:--";
    } catch (e) {
      return "--:--";
    }
  }

  // Calcula a hora baseado na string de offset UTC (ex: "UTC+05:30")
  String _calculateTimeFromOffset(String offsetStr) {
    try {
      DateTime nowUtc = DateTime.now().toUtc();
      String cleanOffset = offsetStr.replaceAll('UTC', '').trim();
      if (cleanOffset.isEmpty) return DateFormat('HH:mm').format(nowUtc);

      bool isNegative = cleanOffset.startsWith('-');
      String digits = cleanOffset.replaceAll(RegExp(r'[^0-9:]'), '');
      List<String> parts = digits.split(':');

      int hours = int.parse(parts[0]);
      int minutes = parts.length > 1 ? int.parse(parts[1]) : 0;

      Duration duration = Duration(hours: hours, minutes: minutes);
      DateTime target = isNegative
          ? nowUtc.subtract(duration)
          : nowUtc.add(duration);

      return DateFormat('HH:mm').format(target);
    } catch (_) {
      return "--:--";
    }
  }

  // --- LÓGICA DA API ---
  // Procura dados detalhados do país no serviço RestCountries
  Future<Map<String, dynamic>?> _fetchCountryData(String code) async {
    try {
      final response = await http.get(
        Uri.parse('https://restcountries.com/v3.1/alpha/$code'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final country = data[0];

        String currencyName =
            (country['currencies'] as Map?)?.values.first['name'] ?? 'N/A';
        String currencySymbol =
            (country['currencies'] as Map?)?.values.first['symbol'] ?? '';

        // Correção manual para países que mudaram de moeda ou têm dados desatualizados na API
        if (code.toUpperCase() == 'BG') {
          currencyName = 'Euro';
          currencySymbol = '€';
        }

        final List<dynamic>? capitalsList = country['capital'];
        final String capitals = capitalsList != null
            ? capitalsList.join(', ')
            : 'N/A';
        final List<dynamic> timezones = country['timezones'] ?? [];

        return {
          'capital': capitals,
          'population': country['population'] ?? 0,
          'region': country['region'] ?? 'N/A',
          'subregion': country['subregion'] ?? 'N/A',
          'languages':
              (country['languages'] as Map?)?.values.join(', ') ?? 'N/A',
          'currency': currencyName,
          'currencySymbol': currencySymbol,
          'capitalTime': _getCountryTime(code, timezones),
        };
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return null;
  }

  // Exibe o painel inferior (Bottom Sheet) com informações do país clicado
  void _showCountryInfoSheet(
    BuildContext context,
    String countryCode,
    String countryName,
  ) {
    // Função auxiliar para os ícones (podes colocar fora do build)
    IconData _getTransportIcon(String? transport) {
      switch (transport) {
        case 'car':
          return Icons.directions_car;
        case 'boat':
          return Icons.directions_boat;
        case 'train':
          return Icons.train;
        default:
          return Icons.flight_takeoff;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool showTripForm = false;
        Map<String, dynamic>? tripToEdit;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final user = SessionManager().currentUser;
            final countryData =
                user?.visitedCountries[countryCode.toUpperCase()];

            List<dynamic> trips = [];
            if (countryData is Map && countryData['trips'] != null) {
              trips = List.from(countryData['trips']);

              // ORDENAR: Da viagem mais antiga para a mais recente
              trips.sort((a, b) {
                int yearComp = (a['year'] as int).compareTo(b['year'] as int);
                if (yearComp != 0) return yearComp;
                DateTime? dateA = a['startDate'] != null
                    ? DateTime.parse(a['startDate'])
                    : null;
                DateTime? dateB = b['startDate'] != null
                    ? DateTime.parse(b['startDate'])
                    : null;
                if (dateA != null && dateB != null)
                  return dateA.compareTo(dateB);
                return 0;
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 15,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra de arraste
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CABEÇALHO
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 70,
                            height: 45,
                            child: countryCode.toUpperCase() == 'XK'
                                ? Image.asset(
                                    'assets/images/Flag_of_Kosovo.svg.webp',
                                    fit: BoxFit.cover,
                                  )
                                : country_flags.CountryFlag.fromCountryCode(
                                    countryCode,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            countryName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // DADOS DA API
                    if (!showTripForm)
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchCountryData(countryCode),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasData && snapshot.data != null) {
                            return _buildDetailsGrid(snapshot.data!);
                          }
                          return const Text("Information unavailable.");
                        },
                      ),

                    const SizedBox(height: 15),

                    // HISTÓRICO DE VIAGENS
                    if (trips.isNotEmpty && !showTripForm) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Your Journeys",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...trips.map((trip) {
                        // Formatação do intervalo de datas
                        String dateDisplay = "";
                        if (trip['startDate'] != null) {
                          DateTime start = DateTime.parse(trip['startDate']);
                          dateDisplay = DateFormat('dd/MM/yyyy').format(start);
                          if (trip['endDate'] != null) {
                            DateTime end = DateTime.parse(trip['endDate']);
                            dateDisplay +=
                                " - ${DateFormat('dd/MM/yyyy').format(end)}";
                          }
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getTransportIcon(trip['transport']),
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            "Trip in ${trip['year']}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: dateDisplay.isNotEmpty
                              ? Text(dateDisplay)
                              : null,

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botão Editar
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setModalState(() {
                                  tripToEdit = trip;
                                  showTripForm = true;
                                }),
                              ),
                              // Botão Apagar
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  // Confirmar antes de apagar (opcional, mas recomendado)
                                  bool? confirm = await _showDeleteConfirm(
                                    context,
                                  );
                                  if (confirm == true) {
                                    await SessionManager()
                                        .removeTripFromCountry(
                                          countryCode,
                                          trip,
                                        );
                                    setModalState(
                                      () {},
                                    ); // Atualiza a lista no modal
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(),
                    ],

                    const SizedBox(height: 15),

                    // BOTÕES / FORMULÁRIO
                    if (!showTripForm) ...[
                      _buildActionButtons(
                        context,
                        countryCode,
                        onVisitClick: () =>
                            setModalState(() => showTripForm = true),
                      ),
                      if (trips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextButton.icon(
                            onPressed: () => setModalState(() {
                              tripToEdit = null;
                              showTripForm = true;
                            }),
                            icon: const Icon(Icons.add),
                            label: const Text("Add another trip"),
                          ),
                        ),
                    ] else
                      TripDetailsForm(
                        countryName: countryName,
                        initialTrip: tripToEdit,
                        onCancel: () =>
                            setModalState(() => showTripForm = false),
                        onSave: (year, transport, start, end) async {
                          if (tripToEdit != null) {
                            await SessionManager().removeTripFromCountry(
                              countryCode,
                              tripToEdit!,
                            );
                          }

                          await SessionManager().addTripToCountry(
                            countryCode,
                            year: year,
                            transport: transport,
                            startDate: start,
                            endDate: end,
                          );
                          setModalState(() {
                            showTripForm = false;
                            tripToEdit = null;
                          });
                        },
                      ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Constrói a grelha de detalhes (População, Capital, Moeda, etc.)
  Widget _buildDetailsGrid(Map<String, dynamic> data) {
    final f = NumberFormat.compact();
    return Column(
      children: [
        // Widget da Hora Local destacado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xff6c63ff).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xff6c63ff).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                color: Color(0xff6c63ff),
                size: 28,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "LOCAL TIME (CAPITAL)",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff4841a8),
                      ),
                    ),
                    Text(
                      data['capitalTime'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff4841a8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _infoTile(
                Icons.location_city,
                "Capital(s)",
                data['capital'],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _infoTile(
                Icons.people,
                "Population",
                f.format(data['population']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _infoTile(Icons.translate, "Languages", data['languages']),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _infoTile(
                Icons.payments,
                "Currency",
                "${data['currency']} (${data['currencySymbol']})",
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _infoTile(Icons.public, "Region", data['region'])),
            const SizedBox(width: 10),
            Expanded(
              child: _infoTile(Icons.map, "Subregion", data['subregion']),
            ),
          ],
        ),
      ],
    );
  }

  // Widget para cada item individual de informação (Ícone + Rótulo + Valor)
  Widget _infoTile(IconData icon, String label, String value) {
    final displayValue = value.replaceAll(', ', '\n');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Constrói os botões de "Visitado" e "Planeado"
  Widget _buildActionButtons(
    BuildContext context,
    String code, {
    required VoidCallback onVisitClick,
  }) {
    final session = SessionManager();

    // Verifica nacionalidade
    final isNationality = _nationalityCountries
        .map((e) => e.toUpperCase())
        .contains(code.toUpperCase());

    if (isNationality) {
      return const Center(
        child: Text(
          '🌍 This is your nationality!',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Estado atual do país
    final bool isVisited = session.isCountryVisitedForCurrentUser(code);
    final bool isPlanned = session.isCountryPlannedForCurrentUser(code);

    return Row(
      children: [
        // BOTÃO DE VISITADO
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(isVisited ? Icons.check : Icons.add),
            label: Text(isVisited ? "Visited" : "Visit"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isVisited
                  ? const Color.fromARGB(255, 31, 131, 212)
                  : Colors.grey[200],
              foregroundColor: isVisited ? Colors.white : Colors.black,
            ),
            onPressed: () async {
              if (isVisited) {
                // Se já visitou, o clique remove diretamente
                await session.toggleVisitedForCurrentUser(code);
                setState(() {}); // Atualiza o mapa atrás
                _updateWidgetMap();
                Navigator.pop(context); // Fecha o modal após remover
              } else {
                // Se NÃO visitou, chama a função que troca o Modal para o Formulário
                onVisitClick();
                print("Clicou no Visitar!");
              }
            },
          ),
        ),

        const SizedBox(width: 10),

        // BOTÃO DE PLANEADO
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(isPlanned ? Icons.bookmark : Icons.bookmark_border),
            label: Text(isPlanned ? "Planned" : "Plan"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPlanned
                  ? const Color.fromARGB(255, 6, 16, 148)
                  : Colors.grey[200],
              foregroundColor: isPlanned ? Colors.white : Colors.black,
            ),
            onPressed: () async {
              await session.togglePlannedForCurrentUser(code);
              setState(() {});
              _updateWidgetMap();
              // Aqui fechamos o modal para dar feedback visual no mapa
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  // Caixa de diálogo para o utilizador escolher o(s) seu(s) país(es) de origem
  Future<void> _showNationalityPicker() async {
    final countries = countryNames.entries
        .map((e) => {'code': e.key, 'name': e.value})
        .toList();
    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final selectedSet = <String>{};
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            final query = searchController.text.toLowerCase();
            final filtered = countries
                .where((c) => c['name']!.toLowerCase().contains(query))
                .toList();
            return AlertDialog(
              title: const Text('Select your nationalities'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return CheckboxListTile(
                            value: selectedSet.contains(c['code']),
                            onChanged: (val) => setState(
                              () => val!
                                  ? selectedSet.add(c['code']!)
                                  : selectedSet.remove(c['code']),
                            ),
                            title: Text(c['name']!),
                            secondary: buildFlag(
                              c['code']!,
                              width: 45,
                              height: 30,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, []),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedSet.toList()),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _nationalityCountries = selected.toSet();
      });
      await SessionManager().updateNationalities(selected);
      _updateWidgetMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset("assets/images/airplane-tilt.svg", width: 40),
        automaticallyImplyLeading: false,
      ),
      // Barra de navegação inferior que controla o conteúdo do body
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() => currentPageIndex = index);
          if (index == 0) {
            // Pequeno atraso para garantir que a transição acabou antes de atualizar o widget
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) _updateWidgetMap();
            });
          }
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.image), label: 'Gallery'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),

      // Exibe a página correspondente ao índice selecionado
      body: <Widget>[
        Stack(
          children: [
            Column(
              children: [
                // Barra de pesquisa de países no mapa
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search countries...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                // Se estiver a pesquisar, mostra lista. Se não, mostra o Mapa.
                _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : Expanded(
                        child: RepaintBoundary(
                          key: _mapKey,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            maxScale: 20.0,
                            minScale: 1.0,
                            child: AnimatedBuilder(
                              // Ouve vários notifiers para repintar o mapa quando algo muda
                              animation: Listenable.merge([
                                SessionManager().visitedCountNotifier,
                                SessionManager().visitedColorNotifier,
                                SessionManager().plannedColorNotifier,
                                SessionManager().nationalityColorNotifier,
                              ]),
                              builder: (context, child) {
                                final session = SessionManager();
                                final user = session.getCurrentUser();
                                final visited = user?.visitedCountries ?? {};
                                final planned = user?.plannedCountries ?? {};
                                final nationalities = user?.nationalities ?? [];

                                // Mapeia cada país à sua cor correspondente (Visitado, Planeado ou Origem)
                                final Map<String, Color> colorMap = {};

                                for (var code in planned) {
                                  colorMap[normalizeCountryCode(code)] =
                                      session.plannedColorNotifier.value;
                                }
                                for (var code in visited.keys) {
                                  colorMap[normalizeCountryCode(code)] =
                                      session.visitedColorNotifier.value;
                                }
                                for (var code in nationalities) {
                                  colorMap[normalizeCountryCode(code)] =
                                      session.nationalityColorNotifier.value;
                                }

                                return SimpleMap(
                                  instructions: SMapWorld.instructions,
                                  defaultColor: Colors.grey.shade400,
                                  colors: colorMap,
                                  countryBorder: const CountryBorder(
                                    color: Colors.black,
                                    width: 0.1,
                                  ),
                                  fit: BoxFit.contain,
                                  callback: (id, name, tapdetails) {
                                    if (id.isNotEmpty) {
                                      _showCountryInfoSheet(
                                        context,
                                        id,
                                        getCountryName(id),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ],
            ),
            // Overlay de carregamento enquanto o widget do Android está a ser gerado
            if (_isUpdatingWidget)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.9),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 15),
                        Text(
                          "Updating Widget Map...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Outras páginas da aplicação
        const FriendsPage(),
        GalleryPage(onBackPressed: () => setState(() => currentPageIndex = 0)),
        ProfilePage(onBackPressed: () => setState(() => currentPageIndex = 0)),
        SettingsPage(
          onBackPressed: () {
            setState(() => currentPageIndex = 0);
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) _updateWidgetMap();
            });
          },
        ),
      ][currentPageIndex],
    );
  }

  // Lista de resultados quando o utilizador escreve na barra de pesquisa
  Widget _buildSearchResults() {
    final query = _searchController.text.toLowerCase();
    final filtered = countryNames.entries
        .where((entry) => entry.value.toLowerCase().contains(query))
        .toList();
    return Expanded(
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final entry = filtered[index];
          final visited = SessionManager()
              .getVisitedCountriesForCurrentUser()
              .contains(entry.key);
          return ListTile(
            leading: buildFlag(entry.key),
            title: Text(entry.value),
            trailing: Icon(
              visited ? Icons.check_circle : Icons.circle_outlined,
              color: visited ? Colors.green : Colors.grey,
            ),
            onTap: () => _showCountryInfoSheet(context, entry.key, entry.value),
          );
        },
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Trip"),
        content: const Text("Are you sure you want to delete this journey?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
