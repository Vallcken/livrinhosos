import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Book {
  final String id;
  String title;
  String author;
  int rating;
  String notes;
  bool read;

  Book({
    required this.id,
    required this.title,
    this.author = '',
    this.rating = 0,
    this.notes = '',
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'rating': rating,
        'notes': notes,
        'read': read,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        author: (j['author'] ?? '') as String,
        rating: (j['rating'] ?? 0) as int,
        notes: (j['notes'] ?? '') as String,
        read: (j['read'] ?? false) as bool,
      );
}

class LibraryStore extends ChangeNotifier {
  static const _kBooks = 'books_v1';
  static const _kTop = 'top_v1';
  static const maxTop = 5;

  final List<Book> _books = [];
  final List<String> _topIds = [];

  List<Book> get readBooks => _books.where((b) => b.read).toList();
  List<Book> get wishlist => _books.where((b) => !b.read).toList();
  List<Book> get top => [
        for (final id in _topIds)
          if (_books.any((b) => b.id == id))
            _books.firstWhere((b) => b.id == id)
      ];
  List<Book> get topCandidates =>
      readBooks.where((b) => !_topIds.contains(b.id)).toList();
  bool isInTop(String id) => _topIds.contains(id);
  bool get topFull => _topIds.length >= maxTop;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBooks);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _books
        ..clear()
        ..addAll(list.map((e) => Book.fromJson(e as Map<String, dynamic>)));
    }
    _topIds
      ..clear()
      ..addAll(prefs.getStringList(_kTop) ?? []);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kBooks, jsonEncode(_books.map((b) => b.toJson()).toList()));
    await prefs.setStringList(_kTop, _topIds);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  void add(Book b) {
    _books.add(b);
    _changed();
  }

  void update(Book b) {
    // Se deixou de ser "lido", sai do Top 5.
    if (!b.read) _topIds.remove(b.id);
    _changed();
  }

  void remove(String id) {
    _books.removeWhere((b) => b.id == id);
    _topIds.remove(id);
    _changed();
  }

  void markAsRead(Book b, int rating) {
    b.read = true;
    b.rating = rating;
    _changed();
  }

  void addToTop(String id) {
    if (topFull || _topIds.contains(id)) return;
    _topIds.add(id);
    _changed();
  }

  void removeFromTop(String id) {
    _topIds.remove(id);
    _changed();
  }

  void reorderTop(int oldIndex, int newIndex) {
    final item = _topIds.removeAt(oldIndex);
    _topIds.insert(newIndex, item);
    _changed();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LibraryStore();
  await store.load();
  runApp(MeusLivrosApp(store: store));
}

class MeusLivrosApp extends StatelessWidget {
  final LibraryStore store;
  const MeusLivrosApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meus Livros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6D4C41),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6D4C41),
        brightness: Brightness.dark,
      ),
      home: HomePage(store: store),
    );
  }
}

class HomePage extends StatefulWidget {
  final LibraryStore store;
  const HomePage({super.key, required this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final titles = ['Livros lidos', 'Quero ler', 'Meu Top 5'];
        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.auto_stories),
              const SizedBox(width: 10),
              Text(titles[_index]),
            ]),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: switch (_index) {
                0 => BookListView(
                    store: store,
                    books: store.readBooks,
                    emptyText:
                        'Nenhum livro lido ainda.\nToque em + para adicionar.',
                  ),
                1 => BookListView(
                    store: store,
                    books: store.wishlist,
                    emptyText:
                        'Sua lista de desejos está vazia.\nToque em + para adicionar.',
                  ),
                _ => TopFiveView(store: store),
              },
            ),
          ),
          floatingActionButton: _index == 2
              ? null
              : FloatingActionButton.extended(
                  onPressed: () =>
                      showBookDialog(context, store, initialRead: _index == 0),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.check_circle_outline),
                selectedIcon: const Icon(Icons.check_circle),
                label: 'Lidos (${store.readBooks.length})',
              ),
              NavigationDestination(
                icon: const Icon(Icons.bookmark_border),
                selectedIcon: const Icon(Icons.bookmark),
                label: 'Desejados (${store.wishlist.length})',
              ),
              const NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Top 5',
              ),
            ],
          ),
        );
      },
    );
  }
}

class Stars extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;
  const Stars(
      {super.key, required this.rating, this.size = 18, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          InkResponse(
            onTap: onChanged == null
                ? null
                : () => onChanged!(i == rating ? 0 : i),
            child: Icon(
              i <= rating ? Icons.star : Icons.star_border,
              size: size,
              color: Colors.amber.shade700,
            ),
          ),
      ],
    );
  }
}

class BookListView extends StatelessWidget {
  final LibraryStore store;
  final List<Book> books;
  final String emptyText;
  const BookListView({
    super.key,
    required this.store,
    required this.books,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final b = books[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(b.title.isEmpty ? '?' : b.title[0].toUpperCase()),
            ),
            title: Text(b.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.author.isNotEmpty) Text(b.author),
                if (b.read) Stars(rating: b.rating),
                if (b.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(b.notes,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    showBookDialog(context, store, book: b);
                  case 'read':
                    final r = await askRating(context);
                    if (r != null) store.markAsRead(b, r);
                  case 'top':
                    if (store.topFull) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Seu Top 5 já está cheio.')));
                    } else {
                      store.addToTop(b.id);
                    }
                  case 'delete':
                    store.remove(b.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                if (!b.read)
                  const PopupMenuItem(
                      value: 'read', child: Text('Marcar como lido')),
                if (b.read && !store.isInTop(b.id))
                  const PopupMenuItem(
                      value: 'top', child: Text('Adicionar ao Top 5')),
                const PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TopFiveView extends StatelessWidget {
  final LibraryStore store;
  const TopFiveView({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final top = store.top;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Arraste para reordenar seus favoritos (${top.length}/${LibraryStore.maxTop}).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: store.topFull || store.topCandidates.isEmpty
                    ? null
                    : () => pickTopBook(context, store),
                icon: const Icon(Icons.add),
                label: const Text('Escolher'),
              ),
            ],
          ),
        ),
        Expanded(
          child: top.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      store.readBooks.isEmpty
                          ? 'Marque alguns livros como lidos para montar seu Top 5.'
                          : 'Seu Top 5 está vazio.\nToque em "Escolher".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: top.length,
                  onReorderItem: store.reorderTop,
                  itemBuilder: (context, i) {
                    final b = top[i];
                    return Card(
                      key: ValueKey(b.id),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i == 0
                              ? Colors.amber.shade600
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Text('${i + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(b.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (b.author.isNotEmpty) Text(b.author),
                            Stars(rating: b.rating),
                          ],
                        ),
                        isThreeLine: b.author.isNotEmpty,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Remover do Top 5',
                              icon: const Icon(Icons.close),
                              onPressed: () => store.removeFromTop(b.id),
                            ),
                            const SizedBox(
                                width: 28), // espaço p/ alça de arrastar
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<int?> askRating(BuildContext context) {
  var rating = 0;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Qual nota você dá?'),
        content: Stars(
            rating: rating,
            size: 36,
            onChanged: (v) => setState(() => rating = v)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, rating),
              child: const Text('Confirmar')),
        ],
      ),
    ),
  );
}

Future<void> pickTopBook(BuildContext context, LibraryStore store) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Adicionar ao Top 5'),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in store.topCandidates)
              ListTile(
                title: Text(b.title),
                subtitle: b.author.isEmpty ? null : Text(b.author),
                trailing: Stars(rating: b.rating, size: 14),
                onTap: () {
                  store.addToTop(b.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
      ],
    ),
  );
}

Future<void> showBookDialog(
  BuildContext context,
  LibraryStore store, {
  Book? book,
  bool initialRead = false,
}) {
  final titleCtrl = TextEditingController(text: book?.title ?? '');
  final authorCtrl = TextEditingController(text: book?.author ?? '');
  final notesCtrl = TextEditingController(text: book?.notes ?? '');
  var read = book?.read ?? initialRead;
  var rating = book?.rating ?? 0;
  final formKey = GlobalKey<FormState>();

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(book == null ? 'Novo livro' : 'Editar livro'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Título *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o título'
                        : null,
                  ),
                  TextFormField(
                    controller: authorCtrl,
                    decoration: const InputDecoration(labelText: 'Autor'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Já li este livro'),
                    value: read,
                    onChanged: (v) => setState(() => read = v),
                  ),
                  if (read) ...[
                    const Text('Nota'),
                    const SizedBox(height: 4),
                    Stars(
                        rating: rating,
                        size: 32,
                        onChanged: (v) => setState(() => rating = v)),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Anotações', alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (book == null) {
                store.add(Book(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  author: authorCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  read: read,
                  rating: read ? rating : 0,
                ));
              } else {
                book
                  ..title = titleCtrl.text.trim()
                  ..author = authorCtrl.text.trim()
                  ..notes = notesCtrl.text.trim()
                  ..read = read
                  ..rating = read ? rating : 0;
                store.update(book);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}
