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
  final String sortField;
  final bool sortAscending;
  final Set<int> selectedIds;
  final ValueChanged<String> onSort;
  final void Function(T, bool)? onSelected;
  final void Function(T) onOpen;
  final void Function(T)? onEdit, onDelete, onRestore;

  const EntityTable({
    super.key,
    required this.items,
    required this.columns,
    required this.idOf,
    required this.isDeleted,
    required this.sortField,
    required this.sortAscending,
    required this.selectedIds,
    required this.onSort,
    required this.onSelected,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  Widget _card(BuildContext context, T item) {
    final title = columns.first.value(item);
    final details = columns.skip(1).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (onSelected != null)
                    Checkbox(
                      value: selectedIds.contains(idOf(item)),
                      onChanged: (value) => onSelected!(item, value ?? false),
                    ),
                  Expanded(
                    child: Tooltip(
                      message: title,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details
                      .map(
                        (column) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${column.label}: ${column.value(item)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Открыть',
                      onPressed: () => onOpen(item),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    if (!isDeleted(item) && onEdit != null)
                      IconButton(
                        tooltip: 'Редактировать',
                        onPressed: () => onEdit!(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if ((isDeleted(item) && onRestore != null) ||
                        (!isDeleted(item) && onDelete != null))
                      IconButton(
                        tooltip: isDeleted(item) ? 'Восстановить' : 'Удалить',
                        onPressed: () => isDeleted(item)
                            ? onRestore!(item)
                            : onDelete!(item),
                        icon: Icon(
                          isDeleted(item)
                              ? Icons.restore
                              : Icons.delete_outline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cards(BuildContext context, double width) {
    if (width < 600) {
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) =>
            SizedBox(height: 210, child: _card(context, items[index])),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 220,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) => _card(context, items[index]),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      if (box.maxWidth < 900) return _cards(context, box.maxWidth);
      final sortIndex = columns.indexWhere(
        (column) => column.sortField == sortField,
      );
      return Scrollbar(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortAscending: sortAscending,
              sortColumnIndex: sortIndex < 0 ? null : sortIndex,
              columns: [
                ...columns.map(
                  (column) => DataColumn(
                    label: Text(column.label),
                    onSort: (_, __) => onSort(column.sortField),
                  ),
                ),
                const DataColumn(label: Text('Действия')),
              ],
              rows: items
                  .map(
                    (item) => DataRow(
                      selected: selectedIds.contains(idOf(item)),
                      onSelectChanged: onSelected == null
                          ? null
                          : (value) => onSelected!(item, value ?? false),
                      color: isDeleted(item)
                          ? WidgetStatePropertyAll(
                              Colors.red.withValues(alpha: 0.06),
                            )
                          : null,
                      cells: [
                        ...columns.map((column) {
                          final value = column.value(item);
                          return DataCell(
                            Tooltip(
                              message: value,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            onTap: () => onOpen(item),
                          );
                        }),
                        DataCell(
                          Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Открыть',
                                onPressed: () => onOpen(item),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              if (!isDeleted(item) && onEdit != null)
                                IconButton(
                                  tooltip: 'Редактировать',
                                  onPressed: () => onEdit!(item),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if ((isDeleted(item) && onRestore != null) ||
                                  (!isDeleted(item) && onDelete != null))
                                IconButton(
                                  tooltip: isDeleted(item)
                                      ? 'Восстановить'
                                      : 'Удалить',
                                  onPressed: () => isDeleted(item)
                                      ? onRestore!(item)
                                      : onDelete!(item),
                                  icon: Icon(
                                    isDeleted(item)
                                        ? Icons.restore
                                        : Icons.delete_outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      );
    },
  );
}
