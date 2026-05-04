import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripDetailsForm extends StatefulWidget {
  final String countryName;
  final Map<String, dynamic>? initialTrip; // Se for nulo, é uma nova viagem
  final Function(int year, String transport, DateTime? start, DateTime? end)
  onSave;
  final VoidCallback? onCancel;

  const TripDetailsForm({
    super.key,
    required this.countryName,
    this.initialTrip, // Adicionado aqui
    required this.onSave,
    this.onCancel,
  });

  @override
  State<TripDetailsForm> createState() => _TripDetailsFormState();
}

class _TripDetailsFormState extends State<TripDetailsForm> {
  late int selectedYear;
  late String selectedTransport;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    // Se estivermos a editar, carregamos os dados. Se não, usamos valores padrão.
    selectedYear = widget.initialTrip?['year'] ?? DateTime.now().year;
    selectedTransport = widget.initialTrip?['transport'] ?? 'plane';
    startDate = widget.initialTrip?['startDate'] != null
        ? DateTime.parse(widget.initialTrip!['startDate'])
        : null;
    endDate = widget.initialTrip?['endDate'] != null
        ? DateTime.parse(widget.initialTrip!['endDate'])
        : null;
  }

  // Função para abrir o calendário nativo
  Future<void> _pickDate(bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (startDate ?? DateTime.now())
          : (endDate ?? DateTime.now()),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          selectedYear = picked.year;
        } else
          endDate = picked;
      });
    }
  }

  final Map<String, IconData> transports = {
    'plane': Icons.flight_takeoff,
    'car': Icons.directions_car,
    'boat': Icons.directions_boat,
    'train': Icons.train,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Memories from ${widget.countryName}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onCancel,
                ),
            ],
          ),
          const SizedBox(height: 15),

          // SECÇÃO: ANO
          const Text(
            "When did you go?",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: selectedYear,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            items: List.generate(50, (index) => DateTime.now().year - index)
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => selectedYear = val!),
          ),

          const SizedBox(height: 20),

          // SECÇÃO: DATAS (OPCIONAL) - Lado a lado para poupar espaço
          const Text(
            "Specific dates (optional)",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    startDate == null
                        ? "Start"
                        : DateFormat('dd/MM/yy').format(startDate!),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    endDate == null
                        ? "End"
                        : DateFormat('dd/MM/yy').format(endDate!),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SECÇÃO: TRANSPORTE
          const Text(
            "How did you get there?",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: transports.entries.map((entry) {
              bool isSelected = selectedTransport == entry.key;
              return GestureDetector(
                onTap: () => setState(() => selectedTransport = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        entry.value,
                        color: isSelected ? Colors.white : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key[0].toUpperCase() + entry.key.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 25),

          // BOTÃO GUARDAR
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => widget.onSave(
                selectedYear,
                selectedTransport,
                startDate,
                endDate,
              ),
              child: const Text(
                "Save Visit",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
