import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import '../user.dart';
import '../session_manager.dart';
import '../profile_manager.dart';
import '../country_names.dart';

class TimelineTrip {
  final String countryCode;
  final String countryName;
  final Map<String, dynamic> tripData;
  final DateTime dateForSort;

  TimelineTrip({
    required this.countryCode,
    required this.countryName,
    required this.tripData,
    required this.dateForSort,
  });
}

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const ProfilePage({super.key, this.onBackPressed});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  late ProfileManager _profileManager;

  @override
  void initState() {
    super.initState();
    _profileManager = ProfileManager();
    _profileManager.loadProfileImage();

    final currentUser = SessionManager().getCurrentUser();
    if (currentUser != null && currentUser.name.isNotEmpty) {
      userNameNotifier.value = currentUser.name;
    }
  }

  // --- AS TUAS FUNÇÕES ORIGINAIS (MANTIDAS) ---
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        _profileManager.setProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  // --- NOVA LÓGICA DA TIMELINE ---
  List<TimelineTrip> _getAllTripsOrdered() {
    final user = SessionManager().getCurrentUser();
    if (user == null) return [];

    List<TimelineTrip> allTrips = [];
    user.visitedCountries.forEach((code, data) {
      if (data is Map && data['trips'] != null) {
        for (var trip in data['trips']) {
          DateTime sortDate = trip['startDate'] != null
              ? DateTime.parse(trip['startDate'])
              : DateTime(trip['year'] as int, 1, 1);

          allTrips.add(
            TimelineTrip(
              countryCode: code,
              countryName: getCountryName(code),
              tripData: trip,
              dateForSort: sortDate,
            ),
          );
        }
      }
    });

    allTrips.sort((a, b) => b.dateForSort.compareTo(a.dateForSort));
    return allTrips;
  }

  @override
  Widget build(BuildContext context) {
    final allTrips = _getAllTripsOrdered();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 1. CABEÇALHO (O teu código original do Avatar e Nome)
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: ValueListenableBuilder<File?>(
                      valueListenable: _profileManager.profileImageNotifier,
                      builder: (context, profileImage, child) {
                        return CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: profileImage != null
                              ? FileImage(profileImage)
                              : null,
                          child: profileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: userNameNotifier,
                            builder: (context, name, child) => Text(
                              name.isEmpty ? 'Guest' : name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Aqui chamo as bandeiras das nacionalidades como já tinhas
                          _buildNationalitiesRow(),
                        ],
                      ),
                      _buildFriendCodeSection(),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 40),

            // 2. ESTATÍSTICAS RÁPIDAS
            _buildStatsGrid(allTrips.length),

            const SizedBox(height: 32),

            // 3. TIMELINE (A nova secção)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Journey Timeline',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            if (allTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "No trips recorded yet. Start exploring!",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allTrips.length,
                itemBuilder: (context, index) {
                  return _buildTimelineTile(
                    trip: allTrips[index],
                    isFirst: index == 0,
                    isLast: index == allTrips.length - 1,
                  );
                },
              ),

            const SizedBox(height: 20),

            // 4. WORLD EXPLORATION (O teu card de percentagem original)
            _buildWorldExplorationCard(),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS AUXILIARES PARA MANTER O CÓDIGO LIMPO ---

  Widget _buildTimelineTile({
    required TimelineTrip trip,
    required bool isFirst,
    required bool isLast,
  }) {
    return TimelineTile(
      alignment: TimelineAlign.manual,
      lineXY: 0.2,
      isFirst: isFirst,
      isLast: isLast,
      indicatorStyle: IndicatorStyle(
        width: 40,
        height: 40,
        indicator: Container(
          decoration: BoxDecoration(
            color: Colors.blue[700],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(
            _getTransportIcon(trip.tripData['transport']),
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      beforeLineStyle: LineStyle(color: Colors.blue[100]!, thickness: 3),
      startChild: Container(
        constraints: const BoxConstraints(minHeight: 80),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          trip.tripData['year'].toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      ),
      endChild: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: buildFlag(trip.countryCode, width: 30),
            title: Text(
              trip.countryName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: trip.tripData['startDate'] != null
                ? Text(
                    DateFormat('dd/MM/yyyy').format(trip.dateForSort),
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int tripCount) {
    final user = SessionManager().getCurrentUser();
    int countryCount = user?.visitedCountries.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            "Countries",
            countryCount.toString(),
            onTap: () => _showCountriesList(context),
          ),
          // Divisor vertical entre os itens
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
          _statItem("Trips", tripCount.toString()),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
          _statItem(
            "World %",
            "${((countryCount / 250) * 100).toStringAsFixed(1)}%",
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {VoidCallback? onTap}) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Se não for clicável, fica um azul mais escuro ou transparente
        color: onTap != null
            ? Colors.white.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    // Se tiver ação de clique, aplica o efeito de pulsação
    if (onTap != null) {
      return BouncingWidget(onTap: onTap, child: content);
    }

    return content;
  }

  // Encapsulei o teu código original das nacionalidades para não poluir o build
  Widget _buildNationalitiesRow() {
    final user = SessionManager().getCurrentUser();
    final nationalities = user?.nationalities ?? [];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: nationalities.map((code) {
        String displayCode = code.toUpperCase();
        if (displayCode == 'KO' || displayCode == 'KOS') displayCode = 'XK';
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: buildFlag(displayCode, width: 22, height: 16),
        );
      }).toList(),
    );
  }

  Widget _buildFriendCodeSection() {
    final code = SessionManager().getCurrentUser()?.friendCode ?? '---';
    return InkWell(
      onTap: () {
        if (code != '---') {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Code copied!')));
        }
      },
      child: Text(
        code,
        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildWorldExplorationCard() {
    ValueListenableBuilder<int>(
      valueListenable: SessionManager().visitedCountNotifier,
      builder: (context, count, _) {
        final user = SessionManager().getCurrentUser();
        // Combina nacionalidades e países visitados para o cálculo total
        final Set<String> allVisited = {
          ...(user?.nationalities ?? []),
          ...(user?.visitedCountries.keys ?? []),
        };

        final int totalVisitedCount = allVisited.length;
        final double percentValue = (totalVisitedCount / 250).clamp(0.0, 1.0);

        return Column(
          children: [
            // Card com lista expansível de países visitados
            Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Countries Visited',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text('$totalVisitedCount / 250'),
                children: [
                  if (allVisited.isEmpty)
                    const ListTile(title: Text('No countries visited yet.'))
                  else
                    Column(
                      children: allVisited.map((code) {
                        String displayCode = code.toUpperCase();
                        if (displayCode == 'KO' || displayCode == 'KOS')
                          displayCode = 'XK';

                        return ListTile(
                          leading: buildFlag(
                            displayCode,
                            width: 32,
                            height: 22,
                          ),
                          title: Text(getCountryName(displayCode)),
                          subtitle: Text(displayCode),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- CARD DE PERCENTAGEM DE EXPLORAÇÃO DO MUNDO ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'World Exploration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: percentValue,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(percentValue * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
    return Container(); // Substitui pelo teu card original se quiseres manter no fundo
  }
}

IconData _getTransportIcon(String? transport) {
  switch (transport) {
    case 'plane':
      return Icons.flight;
    case 'car':
      return Icons.directions_car;
    case 'train':
      return Icons.train;
    case 'boat':
      return Icons.directions_boat;
    default:
      return Icons.explore;
  }
}

void _showCountriesList(BuildContext context) {
  final user = SessionManager().getCurrentUser();
  final countries = user?.visitedCountries.keys.toList() ?? [];
  countries.sort(
    (a, b) => getCountryName(a).compareTo(getCountryName(b)),
  ); // Ordem alfabética

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Visited Countries",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            if (countries.isEmpty)
              const Text("You haven't visited any countries yet.")
            else
              Expanded(
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final code = countries[index];
                    return ListTile(
                      leading: buildFlag(code, width: 30),
                      title: Text(getCountryName(code)),
                      subtitle: Text(code.toUpperCase()),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BouncingWidget({super.key, required this.child, this.onTap});

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92), // Encolhe
      onTapUp: (_) => setState(() => _scale = 1.0), // Volta ao normal
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
