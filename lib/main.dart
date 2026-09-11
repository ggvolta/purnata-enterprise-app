import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PurnataApp());
}

class PurnataApp extends StatelessWidget {
  const PurnataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Purnata Enterprise',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E5F)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE4E7EC)),
          ),
        ),
      ),
      home: const AppLoader(),
    );
  }
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});
  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  final store = AppStore();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AppScope(store: store, child: const HomeShell());
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required Widget child})
      : super(notifier: store, child: child);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class Project {
  Project({
    required this.id,
    required this.name,
    this.client = '',
    this.location = '',
    this.contractAmount = 0,
    required this.startDate,
  });

  final String id;
  String name;
  String client;
  String location;
  double contractAmount;
  String startDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'client': client,
        'location': location,
        'contractAmount': contractAmount,
        'startDate': startDate,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'],
        name: j['name'],
        client: j['client'] ?? '',
        location: j['location'] ?? '',
        contractAmount: (j['contractAmount'] ?? 0).toDouble(),
        startDate: j['startDate'] ?? today(),
      );
}

class Entry {
  Entry({
    required this.id,
    required this.projectId,
    required this.type,
    required this.title,
    required this.date,
    required this.amount,
    this.note = '',
    this.quantity = 0,
    this.unit = '',
    this.unitPrice = 0,
    this.extra = 0,
  });

  final String id;
  final String projectId;
  final String type; // labor, material, daily, other
  final String title;
  final String date;
  final double amount;
  final String note;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double extra;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'type': type,
        'title': title,
        'date': date,
        'amount': amount,
        'note': note,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'extra': extra,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'],
        projectId: j['projectId'],
        type: j['type'],
        title: j['title'],
        date: j['date'],
        amount: (j['amount'] ?? 0).toDouble(),
        note: j['note'] ?? '',
        quantity: (j['quantity'] ?? 0).toDouble(),
        unit: j['unit'] ?? '',
        unitPrice: (j['unitPrice'] ?? 0).toDouble(),
        extra: (j['extra'] ?? 0).toDouble(),
      );
}

class AppStore extends ChangeNotifier {
  static const _projectsKey = 'purnata_projects_v1';
  static const _entriesKey = 'purnata_entries_v1';
  static const _activeKey = 'purnata_active_project_v1';

  final List<Project> projects = [];
  final List<Entry> entries = [];
  String? activeProjectId;

  Project? get activeProject {
    if (projects.isEmpty) return null;
    return projects.firstWhere(
      (p) => p.id == activeProjectId,
      orElse: () => projects.first,
    );
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final projectsRaw = p.getString(_projectsKey);
    final entriesRaw = p.getString(_entriesKey);
    activeProjectId = p.getString(_activeKey);

    if (projectsRaw != null) {
      projects.addAll((jsonDecode(projectsRaw) as List)
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e))));
    }
    if (entriesRaw != null) {
      entries.addAll((jsonDecode(entriesRaw) as List)
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e))));
    }
    if (projects.isNotEmpty &&
        !projects.any((p) => p.id == activeProjectId)) {
      activeProjectId = projects.first.id;
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _projectsKey, jsonEncode(projects.map((e) => e.toJson()).toList()));
    await p.setString(
        _entriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    if (activeProjectId != null) await p.setString(_activeKey, activeProjectId!);
    notifyListeners();
  }

  Future<void> addProject(Project project) async {
    projects.add(project);
    activeProjectId ??= project.id;
    await _save();
  }

  Future<void> selectProject(String id) async {
    activeProjectId = id;
    await _save();
  }

  Future<void> deleteProject(String id) async {
    projects.removeWhere((p) => p.id == id);
    entries.removeWhere((e) => e.projectId == id);
    activeProjectId = projects.isEmpty ? null : projects.first.id;
    await _save();
  }

  Future<void> addEntry(Entry entry) async {
    entries.add(entry);
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
    await _save();
  }

  List<Entry> entriesFor(String? projectId, {String? type}) {
    var result = entries.where((e) => e.projectId == projectId).toList();
    if (type != null) result = result.where((e) => e.type == type).toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  double total(String? projectId, [String? type]) => entriesFor(projectId, type: type)
      .fold(0.0, (sum, e) => sum + e.amount);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  final pages = const [
    DashboardPage(),
    LaborPage(),
    MaterialsPage(),
    CostsPage(),
    ProjectsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purnata Enterprise', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Contractor Manager', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Labor'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Materials'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Costs'),
          NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: 'Projects'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.activeProject;
    if (p == null) return const EmptyProjectMessage();

    final labor = s.total(p.id, 'labor');
    final materials = s.total(p.id, 'material');
    final daily = s.total(p.id, 'daily');
    final other = s.total(p.id, 'other');
    final total = labor + materials + daily + other;
    final remaining = p.contractAmount - total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProjectSelector(project: p),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              if (p.location.isNotEmpty) Text(p.location),
              const SizedBox(height: 16),
              Text('Contract Amount', style: Theme.of(context).textTheme.labelLarge),
              Text(money(p.contractAmount), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            SummaryCard('Labor', labor, Icons.groups),
            SummaryCard('Materials', materials, Icons.inventory_2),
            SummaryCard('Daily Cost', daily, Icons.today),
            SummaryCard('Other Cost', other, Icons.receipt),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              MoneyRow(label: 'Total Project Cost', value: total, strong: true),
              const Divider(height: 24),
              MoneyRow(label: remaining >= 0 ? 'Remaining Budget' : 'Over Budget', value: remaining.abs(), strong: true),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppScope(store: s, child: const ReportPage()))),
          icon: const Icon(Icons.assessment_outlined),
          label: const Text('View Project Report'),
        ),
      ],
    );
  }
}

class ProjectSelector extends StatelessWidget {
  const ProjectSelector({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return DropdownButtonFormField<String>(
      value: project.id,
      decoration: const InputDecoration(labelText: 'Active project', prefixIcon: Icon(Icons.business)),
      items: s.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
      onChanged: (v) { if (v != null) s.selectProject(v); },
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard(this.label, this.value, this.icon, {super.key});
  final String label;
  final double value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        FittedBox(child: Text(money(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      ]),
    ),
  );
}

class LaborPage extends StatelessWidget {
  const LaborPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.activeProject;
    if (p == null) return const EmptyProjectMessage();
    final items = s.entriesFor(p.id, type: 'labor');
    return EntryListPage(
      title: 'Labor Payments',
      total: s.total(p.id, 'labor'),
      items: items,
      emptyText: 'No labor payments yet.',
      addLabel: 'Add Labor Payment',
      onAdd: () => showLaborDialog(context, s, p),
    );
  }
}

class MaterialsPage extends StatelessWidget {
  const MaterialsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.activeProject;
    if (p == null) return const EmptyProjectMessage();
    final items = s.entriesFor(p.id, type: 'material');
    return EntryListPage(
      title: 'Material Purchases',
      total: s.total(p.id, 'material'),
      items: items,
      emptyText: 'No material purchases yet.',
      addLabel: 'Add Material Purchase',
      onAdd: () => showMaterialDialog(context, s, p),
    );
  }
}

class CostsPage extends StatelessWidget {
  const CostsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.activeProject;
    if (p == null) return const EmptyProjectMessage();
    final items = [...s.entriesFor(p.id, type: 'daily'), ...s.entriesFor(p.id, type: 'other')]
      ..sort((a,b) => b.date.compareTo(a.date));
    return EntryListPage(
      title: 'Daily & Other Costs',
      total: s.total(p.id, 'daily') + s.total(p.id, 'other'),
      items: items,
      emptyText: 'No daily or other costs yet.',
      addLabel: 'Add Cost',
      onAdd: () => showCostDialog(context, s, p),
    );
  }
}

class EntryListPage extends StatelessWidget {
  const EntryListPage({super.key, required this.title, required this.total, required this.items, required this.emptyText, required this.addLabel, required this.onAdd});
  final String title;
  final double total;
  final List<Entry> items;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(money(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            ])),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
        )),
      ),
      Expanded(
        child: items.isEmpty
          ? Center(child: Text(emptyText))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = items[i];
                final detail = [
                  e.date,
                  if (e.quantity > 0) '${plain(e.quantity)} ${e.unit}${e.unitPrice > 0 ? ' × ${money(e.unitPrice)}' : ''}',
                  if (e.note.isNotEmpty) e.note,
                ].join(' • ');
                return Card(child: ListTile(
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(detail),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') s.deleteEntry(e.id);
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                    ),
                  ]),
                ));
              },
            ),
      ),
    ]);
  }
}

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProjectDialog(context, s),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      body: s.projects.isEmpty
        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Create your first project to start recording costs.')))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: s.projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = s.projects[i];
              final active = p.id == s.activeProject?.id;
              final spent = s.total(p.id);
              return Card(child: ListTile(
                leading: CircleAvatar(child: Icon(active ? Icons.check : Icons.business)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${p.location.isEmpty ? 'No location' : p.location}\nSpent ${money(spent)} of ${money(p.contractAmount)}'),
                isThreeLine: true,
                onTap: () => s.selectProject(p.id),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'select') s.selectProject(p.id);
                    if (v == 'delete') confirmDeleteProject(context, s, p);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'select', child: Text('Set active')),
                    PopupMenuItem(value: 'delete', child: Text('Delete project')),
                  ],
                ),
              ));
            },
          ),
    );
  }
}

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.activeProject;
    if (p == null) return const Scaffold(body: EmptyProjectMessage());
    final labor = s.total(p.id, 'labor');
    final materials = s.total(p.id, 'material');
    final daily = s.total(p.id, 'daily');
    final other = s.total(p.id, 'other');
    final total = labor + materials + daily + other;
    final balance = p.contractAmount - total;
    return Scaffold(
      appBar: AppBar(title: const Text('Project Report')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (p.client.isNotEmpty) Text('Client: ${p.client}'),
          if (p.location.isNotEmpty) Text('Location: ${p.location}'),
          Text('Start date: ${p.startDate}'),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          MoneyRow(label: 'Contract Amount', value: p.contractAmount, strong: true),
          const Divider(),
          MoneyRow(label: 'Labor', value: labor),
          MoneyRow(label: 'Materials', value: materials),
          MoneyRow(label: 'Daily Cost', value: daily),
          MoneyRow(label: 'Other Cost', value: other),
          const Divider(),
          MoneyRow(label: 'Total Cost', value: total, strong: true),
          const SizedBox(height: 8),
          MoneyRow(label: balance >= 0 ? 'Remaining / Estimated Margin' : 'Over Budget', value: balance.abs(), strong: true),
        ]))),
      ]),
    );
  }
}

class MoneyRow extends StatelessWidget {
  const MoneyRow({super.key, required this.label, required this.value, this.strong = false});
  final String label;
  final double value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w400))),
      Text(money(value), style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
    ]),
  );
}

class EmptyProjectMessage extends StatelessWidget {
  const EmptyProjectMessage({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Text('No project yet. Open Projects and create your first project.'),
    ),
  );
}

Future<void> showProjectDialog(BuildContext context, AppStore s) async {
  final name = TextEditingController();
  final client = TextEditingController();
  final location = TextEditingController();
  final amount = TextEditingController();
  await showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text('New Project'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name *')),
      const SizedBox(height: 10),
      TextField(controller: client, decoration: const InputDecoration(labelText: 'Client name')),
      const SizedBox(height: 10),
      TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
      const SizedBox(height: 10),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Contract amount (৳)')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (name.text.trim().isEmpty) return;
        s.addProject(Project(
          id: newId(),
          name: name.text.trim(),
          client: client.text.trim(),
          location: location.text.trim(),
          contractAmount: d(amount.text),
          startDate: today(),
        ));
        Navigator.pop(ctx);
      }, child: const Text('Save')),
    ],
  ));
}

Future<void> showLaborDialog(BuildContext context, AppStore s, Project p) async {
  final worker = TextEditingController();
  final days = TextEditingController(text: '1');
  final dailyRate = TextEditingController();
  final overtime = TextEditingController(text: '0');
  final deduction = TextEditingController(text: '0');
  final note = TextEditingController();
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
    double total() => d(days.text) * d(dailyRate.text) + d(overtime.text) - d(deduction.text);
    return AlertDialog(
      title: const Text('Labor Payment'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: worker, decoration: const InputDecoration(labelText: 'Worker / team name *')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: days, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Days'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: dailyRate, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Daily rate'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: overtime, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Overtime / Extra'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: deduction, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Deduction'))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Work / note')),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: Text('Payment: ${money(total())}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (worker.text.trim().isEmpty || total() < 0) return;
          s.addEntry(Entry(
            id: newId(), projectId: p.id, type: 'labor', title: worker.text.trim(), date: today(), amount: total(),
            note: note.text.trim(), quantity: d(days.text), unit: 'day', unitPrice: d(dailyRate.text), extra: d(overtime.text) - d(deduction.text),
          ));
          Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    );
  }));
}

Future<void> showMaterialDialog(BuildContext context, AppStore s, Project p) async {
  const materials = ['Bricks', 'Stone', 'Sand', 'Bitumen', 'Diesel', 'Rod', 'Cement', 'Other'];
  const units = ['pcs', 'cft', 'kg', 'ton', 'liter', 'bag', 'load', 'unit'];
  String material = materials.first;
  String unit = units.first;
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();
  final transport = TextEditingController(text: '0');
  final note = TextEditingController();
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
    double total() => d(qty.text) * d(price.text) + d(transport.text);
    return AlertDialog(
      title: const Text('Material Purchase'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: material, decoration: const InputDecoration(labelText: 'Material'), items: materials.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => material = v!)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: qty, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'Unit'), items: units.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => unit = v!))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: price, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price per unit (৳)')),
        const SizedBox(height: 10),
        TextField(controller: transport, onChanged: (_) => setState((){}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Transport / extra cost (৳)')),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Supplier / note')),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: Text('Total: ${money(total())}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (d(qty.text) <= 0 || d(price.text) < 0) return;
          s.addEntry(Entry(
            id: newId(), projectId: p.id, type: 'material', title: material, date: today(), amount: total(), note: note.text.trim(),
            quantity: d(qty.text), unit: unit, unitPrice: d(price.text), extra: d(transport.text),
          ));
          Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    );
  }));
}

Future<void> showCostDialog(BuildContext context, AppStore s, Project p) async {
  String type = 'daily';
  final title = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
    title: const Text('Add Cost'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'daily', label: Text('Daily')), ButtonSegment(value: 'other', label: Text('Other'))],
        selected: {type},
        onSelectionChanged: (v) => setState(() => type = v.first),
      ),
      const SizedBox(height: 12),
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Cost name *', hintText: 'Transport, food, machine rent...')),
      const SizedBox(height: 10),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (৳)')),
      const SizedBox(height: 10),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (title.text.trim().isEmpty || d(amount.text) <= 0) return;
        s.addEntry(Entry(id: newId(), projectId: p.id, type: type, title: title.text.trim(), date: today(), amount: d(amount.text), note: note.text.trim()));
        Navigator.pop(ctx);
      }, child: const Text('Save')),
    ],
  )));
}

Future<void> confirmDeleteProject(BuildContext context, AppStore s, Project p) async {
  final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Delete project?'),
    content: Text('This will permanently delete “${p.name}” and all of its cost records from this phone.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
    ],
  ));
  if (yes == true) s.deleteProject(p.id);
}

String today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

double d(String value) => double.tryParse(value.trim()) ?? 0;

String plain(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

String money(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final chars = parts[0].split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) out.add(',');
    out.add(chars[i]);
  }
  final integer = out.reversed.join();
  final decimals = parts[1] == '00' ? '' : '.${parts[1]}';
  return '${negative ? '-' : ''}৳$integer$decimals';
}
