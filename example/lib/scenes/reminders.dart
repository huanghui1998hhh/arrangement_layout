import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';

import 'scene_chrome.dart';

/// 提醒事项：列表集合与选中列表，只允许左右分栏。
///
/// 书本姿态时折痕成了天然的分隔线；外屏和立在桌上时切不开，只留列表，
/// 点进去再用导航推出详情。
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _board = _Board();

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      title: '提醒事项',
      api: '.split.axes(.horizontal) · ratio 0.38',
      seed: const Color(0xFF0A84FF),
      notes: const [
        PoseNote(DevicePose.flat, '左右两栏，列表按 38% 的比例占左侧，右侧是选中的列表。'),
        PoseNote(DevicePose.book, '分界直接落在折痕上，比例让位。弯曲的中线成了两栏的分隔。'),
        PoseNote(
          DevicePose.tabletop,
          '只允许水平轴，上下切不开：只留列表，放在折痕较大的一侧，不跨过折痕。点进去推出详情。',
        ),
        PoseNote(DevicePose.closed, '外屏太窄，两边都达不到最小宽度，只留列表。右栏的状态仍然保留。'),
      ],
      body: ArrangementLayout(
        style: const ArrangementStyle.split(
          axes: {Axis.horizontal},
          ratio: 0.38,
          minPrimaryExtent: 300,
          minSecondaryExtent: 360,
        ),
        primary: _ListsPane(board: _board),
        secondary: ListenableBuilder(
          listenable: _board,
          builder: (context, _) =>
              _ListDetail(board: _board, index: _board.selected),
        ),
      ),
    );
  }
}

class _Todo {
  _Todo(this.title, [this.note]);

  final String title;
  final String? note;
  bool done = false;
}

class _TodoList {
  _TodoList(this.name, this.color, this.icon, this.items);

  final String name;
  final Color color;
  final IconData icon;
  final List<_Todo> items;

  int get open => items.where((item) => !item.done).length;
}

class _Board extends ChangeNotifier {
  int selected = 0;

  final lists = <_TodoList>[
    _TodoList('今天', const Color(0xFF0A84FF), Icons.today_rounded, [
      _Todo('给 iPhone Duo 适配折痕', '书本姿态要让分界贴着折痕'),
      _Todo('评审 ArrangementLayout 的 PR'),
      _Todo('18:30 健身房'),
      _Todo('回复设计组的动效反馈', '桌面姿态控件放下半'),
    ]),
    _TodoList('京都旅行', const Color(0xFFFF9500), Icons.flight_rounded, [
      _Todo('订伏见稻荷附近的民宿'),
      _Todo('买 JR Pass'),
      _Todo('换一点日元现金'),
      _Todo('查岚山小火车时刻表'),
      _Todo('带转换插头'),
    ]),
    _TodoList('购物', const Color(0xFF34C759), Icons.shopping_basket_rounded, [
      _Todo('燕麦奶 ×2'),
      _Todo('咖啡豆（中深烘）'),
      _Todo('牙膏'),
    ]),
    _TodoList('读书', const Color(0xFFAF52DE), Icons.auto_stories_rounded, [
      _Todo('《设计心理学》第 4 章'),
      _Todo('整理上周的读书笔记'),
    ]),
    _TodoList('家务', const Color(0xFFFF375F), Icons.home_rounded, [
      _Todo('给绿萝换盆'),
      _Todo('交物业费'),
      _Todo('洗窗帘'),
    ]),
  ];

  void select(int index) {
    selected = index;
    notifyListeners();
  }

  void toggle(int list, _Todo todo) {
    todo.done = !todo.done;
    notifyListeners();
  }

  void add(int list) {
    lists[list].items.add(_Todo('新提醒事项'));
    notifyListeners();
  }
}

// MARK: 列表集合

class _ListsPane extends StatelessWidget {
  const _ListsPane({required this.board});

  final _Board board;

  void _open(BuildContext context, int index) {
    board.select(index);
    if (ArrangementPane.of(context).presentation !=
        ArrangementPresentation.primaryOnly) {
      return;
    }
    final theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Theme(
          data: theme,
          child: Scaffold(
            appBar: AppBar(title: Text(board.lists[index].name)),
            body: ListenableBuilder(
              listenable: board,
              builder: (context, _) =>
                  _ListDetail(board: board, index: index, showTitle: false),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final split =
        ArrangementPane.of(context).presentation !=
        ArrangementPresentation.primaryOnly;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: ListenableBuilder(
        listenable: board,
        builder: (context, _) {
          final open = board.lists.fold(0, (sum, list) => sum + list.open);
          final done = board.lists.fold(
            0,
            (sum, list) => sum + list.items.length - list.open,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SmartTile(
                      icon: Icons.today_rounded,
                      color: const Color(0xFF0A84FF),
                      label: '今天',
                      count: board.lists[0].open,
                      onTap: () => _open(context, 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmartTile(
                      icon: Icons.inbox_rounded,
                      color: const Color(0xFF3A3A3C),
                      label: '全部',
                      count: open,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SmartTile(
                      icon: Icons.flag_rounded,
                      color: const Color(0xFFFF9500),
                      label: '旗标',
                      count: 2,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmartTile(
                      icon: Icons.check_rounded,
                      color: const Color(0xFF8E8E93),
                      label: '已完成',
                      count: done,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '我的列表',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < board.lists.length; i++)
                      ListTile(
                        selected: split && i == board.selected,
                        selectedTileColor: scheme.primaryContainer,
                        onTap: () => _open(context, i),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: board.lists[i].color,
                          child: Icon(
                            board.lists[i].icon,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(board.lists[i].name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${board.lists[i].open}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            if (!split) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmartTile extends StatelessWidget {
  const _SmartTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color,
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: 详情

class _ListDetail extends StatelessWidget {
  const _ListDetail({
    required this.board,
    required this.index,
    this.showTitle = true,
  });

  final _Board board;
  final int index;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final list = board.lists[index];
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: ListView(
                key: ValueKey(index),
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                children: [
                  if (showTitle)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            list.name,
                            style: TextStyle(
                              color: list.color,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${list.open}',
                          style: TextStyle(
                            color: list.color,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  for (final todo in list.items)
                    _TodoRow(
                      todo: todo,
                      color: list.color,
                      onTap: () => board.toggle(index, todo),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: list.color),
                onPressed: () => board.add(index),
                icon: const Icon(Icons.add_circle_rounded),
                label: const Text(
                  '新提醒事项',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.todo,
    required this.color,
    required this.onTap,
  });

  final _Todo todo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.done ? color : Colors.transparent,
                border: Border.all(
                  color: todo.done ? color : scheme.outline,
                  width: 2,
                ),
              ),
              child: todo.done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: todo.done ? 0.45 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 17,
                        decoration: todo.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (todo.note != null)
                      Text(
                        todo.note!,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
