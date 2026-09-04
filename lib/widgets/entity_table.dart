import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label, sortField;
  final String Function(T) value;
  const TableColumnSpec(this.label, this.sortField, this.value);
}

class EntityTable<T> extends StatelessWidget {
  final List<T> items;
  final List<TableColumnSpec<T>> columns;
  final int Function(T) idOf;
  final bool Function(T) isDeleted;
  final Set<int> selected;
  final String sortField;
  final bool sortAscending;
  final ValueChanged<int> onToggle;
  final ValueChanged<String> onSort;
  final void Function(T) onDelete, onRestore;
  const EntityTable({
    super.key,
    required this.items,
    required this.columns,
    required this.idOf,
    required this.isDeleted,
    required this.selected,
    required this.sortField,
    required this.sortAscending,
    required this.onToggle,
    required this.onSort,
    required this.onDelete,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      if (box.maxWidth < 600) {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              child: CheckboxListTile(
                value: selected.contains(idOf(item)),
                onChanged: (_) => onToggle(idOf(item)),
                title: Text(columns.first.value(item)),
                subtitle: Text(
                  columns
                      .skip(1)
                      .map((c) => '${c.label}: ${c.value(item)}')
                      .join('\n'),
                ),
                secondary: IconButton(
                  icon: Icon(
                    isDeleted(item) ? Icons.restore : Icons.delete_outline,
                  ),
                  onPressed: () =>
                      isDeleted(item) ? onRestore(item) : onDelete(item),
                ),
              ),
            );
          },
        );
      }
      final sortIndex = columns.indexWhere((c) => c.sortField == sortField);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortAscending: sortAscending,
          sortColumnIndex: sortIndex < 0 ? null : sortIndex + 1,
          columns: [
            const DataColumn(label: Text('Выбор')),
            ...columns.map(
              (c) => DataColumn(
                label: Text(c.label),
                onSort: (_, __) => onSort(c.sortField),
              ),
            ),
            const DataColumn(label: Text('Действия')),
          ],
          rows: items
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        value: selected.contains(idOf(item)),
                        onChanged: (_) => onToggle(idOf(item)),
                      ),
                    ),
                    ...columns.map((c) => DataCell(Text(c.value(item)))),
                    DataCell(
                      IconButton(
                        tooltip: isDeleted(item) ? 'Восстановить' : 'Удалить',
                        icon: Icon(
                          isDeleted(item)
                              ? Icons.restore
                              : Icons.delete_outline,
                        ),
                        onPressed: () =>
                            isDeleted(item) ? onRestore(item) : onDelete(item),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      );
    },
  );
}
