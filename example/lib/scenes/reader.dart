import 'package:arrangement_layout/arrangement_layout.dart';
import 'package:flutter/material.dart';

import 'scene_chrome.dart';

/// 双页阅读：左页是 primary，右页是 secondary。
///
/// 书本姿态下两页贴着折痕对开，书脊处有阴影；外屏或立在桌上时只留一页，
/// 翻页步长从两页变成一页。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  int _page = 0;

  void _turn(int delta, {required bool spread}) {
    final step = spread ? 2 : 1;
    setState(() {
      _page = (_page + delta * step).clamp(0, _pages.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      title: '双页阅读',
      api: '.split.axes(.horizontal)',
      seed: const Color(0xFF8D6E63),
      notes: const [
        PoseNote(DevicePose.book, '像一本打开的书：两页各占折痕一侧，书脊阴影落在折痕上，一次翻两页。'),
        PoseNote(DevicePose.flat, '横向够宽，同样左右两页，但中间只有一道很浅的分隔。'),
        PoseNote(DevicePose.tabletop, '上下切不开，只留一页，落在折痕较大的一侧，文字不跨折痕。'),
        PoseNote(DevicePose.closed, '外屏只有一页，一次翻一页。第二页的状态保留着。'),
      ],
      body: ColoredBox(
        color: const Color(0xFFE9E1CF),
        child: ArrangementLayout(
          style: const ArrangementStyle.split(
            axes: {Axis.horizontal},
            minPrimaryExtent: 340,
            minSecondaryExtent: 340,
          ),
          primary: _PageSheet(index: _page, onTurn: _turn),
          secondary: _PageSheet(index: _page + 1, onTurn: _turn),
        ),
      ),
    );
  }
}

class _PageSheet extends StatelessWidget {
  const _PageSheet({required this.index, required this.onTurn});

  final int index;
  final void Function(int delta, {required bool spread}) onTurn;

  @override
  Widget build(BuildContext context) {
    final pane = ArrangementPane.of(context);
    final spread = pane.presentation == ArrangementPresentation.splitHorizontal;
    final isLeft = pane.role == ArrangementRole.primary;
    final folded = hasActiveFold(context);
    final spine = !spread ? 0.0 : (folded ? 0.2 : 0.07);
    final page = index < _pages.length ? _pages[index] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final x = details.localPosition.dx / constraints.maxWidth;
            if (x < 0.35 && (isLeft || !spread)) {
              onTurn(-1, spread: spread);
            } else if (x > 0.65 && (!isLeft || !spread)) {
              onTurn(1, spread: spread);
            }
          },
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v.abs() > 200) {
              onTurn(v < 0 ? 1 : -1, spread: spread);
            }
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                stops: const [0, 0.08, 0.3, 1],
                colors: [
                  Color.lerp(const Color(0xFFF8F2E4), Colors.brown, spine)!,
                  Color.lerp(
                    const Color(0xFFF8F2E4),
                    Colors.brown,
                    spine * 0.35,
                  )!,
                  const Color(0xFFF8F2E4),
                  const Color(0xFFF3ECDC),
                ],
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: page == null
                  ? const Center(
                      key: ValueKey('end'),
                      child: Text(
                        '— 完 —',
                        style: TextStyle(
                          color: Color(0xFF8B7E6A),
                          fontSize: 18,
                          letterSpacing: 4,
                        ),
                      ),
                    )
                  : _PageBody(
                      key: ValueKey(index),
                      page: page,
                      number: index + 1,
                      wide: constraints.maxWidth > 560,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    super.key,
    required this.page,
    required this.number,
    required this.wide,
  });

  final _Page page;
  final int number;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2E2A24);
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 72 : 40, 28, wide ? 72 : 40, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '折痕 · ${page.chapter}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9C8F7A),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (page.heading != null) ...[
                    Text(
                      page.heading!,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  for (final paragraph in page.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '\u3000\u3000$paragraph',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 17,
                          height: 1.85,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            '$number',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9C8F7A), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Page {
  const _Page(this.chapter, this.paragraphs, {this.heading});

  final String chapter;
  final String? heading;
  final List<String> paragraphs;
}

const _pages = <_Page>[
  _Page('第一章', heading: '第一章　两块屏', [
    '林澈第一次把那台手机打开的时候，它像一本很薄的书，在掌心里慢慢展平。屏幕中间有一道看不太出来的折痕，只有在侧光下，才会显出一条极细的影子。',
    '他把它合上，外面那块小屏亮着时间；再打开，里面那块大屏接着刚才的页面。好像什么都没发生，又好像什么都换了位置。',
  ]),
  _Page('第一章', [
    '“你看，”他对坐在对面的周遥说，“它知道自己被折起来了。”',
    '周遥把手机从他手里拿过去，没有完全打开，只让它停在一个角度，像一本读到一半、被人随手搁在桌上的书。屏幕上的内容从折痕两边分开，左边是目录，右边是正文，谁也不压着谁。',
    '“折痕成了书脊。”她说。',
  ]),
  _Page('第一章', [
    '林澈做了很多年的界面，习惯把东西放在格子里：左边一栏，右边一栏，中间一条一像素的线。可那条线从来不是真的，它只是画出来的。',
    '现在这条线是真的了。它有宽度，会弯，手指按上去是一块不太听话的地方。按钮不该放在那儿，文字也不该从那儿穿过去。',
  ]),
  _Page('第一章', [
    '“所以你不能自己画那条线，”周遥把手机转了九十度，让下半截平躺在桌面上，上半截立起来，“你得问它，线在哪儿。”',
    '画面自己挪到了上半。播放键、进度条、音量，全都落到了下半，贴着桌面，稳稳当当的。她伸手一点，暂停；再一点，继续。',
  ]),
  _Page('第一章', [
    '林澈看了很久。他忽然明白，这不是为某一种姿势单独做一版界面，而是先说清楚两块内容是什么关系：谁在前，谁在后；谁可以暂时离开，谁必须留下。',
    '剩下的事，交给那道折痕。',
  ]),
  _Page('第二章', heading: '第二章　留下来的那一块', [
    '那天晚上，他把手机合上，揣进口袋，走去地铁站。外屏很窄，只够放下一样东西。',
    '他打开地图，屏幕上只剩一张卡片浮在街道上面，写着最近的一家咖啡馆，走过去四分钟。其余的结果都收了起来，没有消失，只是在等一块更大的地方。',
  ]),
  _Page('第二章', [
    '到了站台，他把手机半打开，像捧着一本书。地图退到左边，右边展开了一整列的店名、评分、距离。他点了其中一家，左边的地图轻轻滑过去，那枚图钉跳了一下。',
    '两边说的是同一件事，只是站在折痕的两侧。',
  ]),
  _Page('第二章', [
    '列车进站，风从隧道里推出来。林澈把手机合上，卡片又回到了外屏，停在他刚才选的那一家。',
    '他想，好的布局大概就是这样：你察觉不到它在变，只觉得东西总在该在的地方。',
  ]),
  _Page('第二章', [
    '第二天上班，他删掉了代码里所有写死的断点，没有“如果宽度大于八百四十”，也没有“如果是折叠屏”。只留下两块内容，和它们之间的一句关系。',
    '测试同事问他，合上的时候右边那栏去哪儿了。',
    '“它还在，”林澈说，“只是暂时不在屏幕上。等你打开，它会从刚才停下的地方继续。”',
  ]),
  _Page('第二章', ['周遥后来在一张便签上写了一句话，贴在他显示器的边框上：', '“别跟折痕较劲，跟它商量。”', '他一直没撕下来。']),
];
