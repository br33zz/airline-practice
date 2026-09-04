import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/list_query.dart';
import '../state/airline_notifier.dart';
import '../widgets/entity_table.dart';

class EntityListScreen<T> extends StatefulWidget {
  final String title, path, filterLabel;
  final Uri uri;
  final AirlineListNotifier<T> notifier;
  final List<String> filters;
  final List<TableColumnSpec<T>> columns;
  final bool Function(T) isDeleted;
  const EntityListScreen({
    super.key,
    required this.title,
    required this.path,
    required this.filterLabel,
    required this.uri,
    required this.notifier,
    required this.filters,
    required this.columns,
    required this.isDeleted,
  });
  @override
  State<EntityListScreen<T>> createState() => _EntityListScreenState<T>();
}

class _EntityListScreenState<T> extends State<EntityListScreen<T>> {
  late final TextEditingController search;
  bool initialized = false;
  @override
  void initState() {
    super.initState();
    search = TextEditingController(
      text: widget.uri.queryParameters['search'] ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (initialized) return;
    initialized = true;
    final p = widget.uri.queryParameters;
    final sort = (p['sort'] ?? 'id,asc').split(',');
    await widget.notifier.applyQuery(
      ListQuery(
        search: p['search'] ?? '',
        filter: p['filter'] ?? '',
        sortField: sort.first,
        sortAscending: sort.length < 2 || sort[1] != 'desc',
        page: int.tryParse(p['page'] ?? '') ?? 1,
        size: int.tryParse(p['size'] ?? '') ?? 10,
        includeDeleted: p['deleted'] == 'true',
      ),
    );
  }

  void _url(ListQuery q) {
    context.go(
      Uri(
        path: widget.path,
        queryParameters: {
          if (q.search.isNotEmpty) 'search': q.search,
          if (q.filter.isNotEmpty) 'filter': q.filter,
          'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
          'page': '${q.page}',
          'size': '${q.size}',
          if (q.includeDeleted) 'deleted': 'true',
        },
      ).toString(),
    );
  }

  Future<void> _apply(ListQuery q) async {
    _url(q);
    await widget.notifier.applyQuery(q);
  }

  Future<void> _confirmDelete(T item) async {
    final hard = widget.isDeleted(item);
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(hard ? 'Удалить навсегда?' : 'Удалить запись?'),
            content: Text(
              hard
                  ? 'Восстановить запись после этого будет невозможно.'
                  : 'Запись можно будет восстановить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await widget.notifier.remove(widget.notifier.idOf(item), hard: hard);
    }
  }

  Widget _content(AirlineListNotifier<T> n) {
    if (n.status == LoadStatus.loading || n.status == LoadStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    if (n.status == LoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            Text(n.error ?? 'Ошибка'),
            FilledButton(onPressed: n.load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (n.result.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64),
            Text('Ничего не найдено'),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: EntityTable<T>(
        items: n.result.items,
        columns: widget.columns,
        idOf: n.idOf,
        isDeleted: widget.isDeleted,
        selected: n.selected,
        sortField: n.query.sortField,
        sortAscending: n.query.sortAscending,
        onToggle: n.toggle,
        onSort: (field) => _apply(
          n.query.copyWith(
            sortField: field,
            sortAscending: field == n.query.sortField
                ? !n.query.sortAscending
                : true,
          ),
        ),
        onDelete: _confirmDelete,
        onRestore: (x) => n.restoreOne(n.idOf(x)),
      ),
    );
  }

  Widget _pager(AirlineListNotifier<T> n) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        tooltip: 'Первая',
        onPressed: n.result.hasPrevious
            ? () => _apply(n.query.copyWith(page: 1))
            : null,
        icon: const Icon(Icons.first_page),
      ),
      IconButton(
        tooltip: 'Предыдущая',
        onPressed: n.result.hasPrevious
            ? () => _apply(n.query.copyWith(page: n.result.page - 1))
            : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        'Страница ${n.result.page} из ${n.result.totalPages} • Всего: ${n.result.total}',
      ),
      IconButton(
        tooltip: 'Следующая',
        onPressed: n.result.hasNext
            ? () => _apply(n.query.copyWith(page: n.result.page + 1))
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
      IconButton(
        tooltip: 'Последняя',
        onPressed: n.result.hasNext
            ? () => _apply(n.query.copyWith(page: n.result.totalPages))
            : null,
        icon: const Icon(Icons.last_page),
      ),
      const SizedBox(width: 12),
      DropdownButton<int>(
        value: n.query.size,
        items: [10, 25, 50]
            .map((x) => DropdownMenuItem(value: x, child: Text('$x записей')))
            .toList(),
        onChanged: (v) => _apply(n.query.copyWith(size: v)),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.notifier,
    builder: (_, __) {
      final n = widget.notifier;
      return Scaffold(
        appBar: AppBar(
          title: Text('Авиакомпания • ${widget.title}'),
          actions: [
            TextButton.icon(
              onPressed: () => context.go(
                widget.path == '/flights' ? '/passengers' : '/flights',
              ),
              icon: const Icon(Icons.swap_horiz),
              label: Text(widget.path == '/flights' ? 'Пассажиры' : 'Рейсы'),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: search,
                          onChanged: (v) {
                            n.search(v);
                            Future.delayed(
                              const Duration(milliseconds: 360),
                              () {
                                if (mounted && search.text == v) {
                                  _url(n.query.copyWith(search: v));
                                }
                              },
                            );
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Поиск',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String>(
                          initialValue: n.query.filter,
                          decoration: InputDecoration(
                            labelText: widget.filterLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: ['', ...widget.filters]
                              .map(
                                (x) => DropdownMenuItem(
                                  value: x,
                                  child: Text(x.isEmpty ? 'Все' : x),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              _apply(n.query.copyWith(filter: v ?? '')),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Показать удалённые'),
                        selected: n.query.includeDeleted,
                        onSelected: (v) =>
                            _apply(n.query.copyWith(includeDeleted: v)),
                      ),
                      if (n.selected.isNotEmpty)
                        FilledButton.icon(
                          onPressed: n.removeSelected,
                          icon: const Icon(Icons.delete),
                          label: Text('Удалить (${n.selected.length})'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _content(n)),
                  const SizedBox(height: 12),
                  _pager(n),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}
