# ArrangementView 规格

把 iOS 27.1 的 `ArrangementView` / `UIArrangementViewController` 做成跨平台 Flutter 布局容器时，按这份规格实现。容器描述两块内容的关系，由环境决定可见性和 frame。铰链角度只驱动交互效果，不参与这块布局。

本文件是布局规格，不是 API 教程。现有的 `ArrangementState` 继续负责折痕、挖孔和铰链读数；这里规定这些读数如何变成两块内容的摆放。

## 来源

Apple 的页面可以打开，但正文由前端渲染，抓取时拿不到段落。下面把能核对到的材料和置信度分开。

| 材料 | 地址 | 怎么用 |
| --- | --- | --- |
| iPhone Duo 开发者入口 | <https://developer.apple.com/iphone-duo/> | 官方索引。指向 HIG、Technology Overview 和五场 Tech Talk |
| Preparing your app for iPhone Duo | <https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo> | 官方总览。页面存在，正文未取到 |
| Designing for iPhone Duo | <https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo> | 官方 HIG。页面存在，正文未取到 |
| Strike a pose（Tech Talk 111463） | <https://developer.apple.com/videos/play/tech-talks/111463/> | 形态、输入、放置禁则的主要来源。转述带时间戳 |
| Design for iPhone Duo（Tech Talk 111466） | <https://developer.apple.com/videos/play/tech-talks/111466/> | 姿态、位移、外屏延续 |
| iPhone Duo by Examples | <https://github.com/artemnovichkov/iPhone-Duo-by-Examples> | iOS 27.1 模拟器上的 API 表面。作者标明 “Good to Know” 不是文档保证 |
| Android 折叠屏 | [Learn about foldables](https://developer.android.com/develop/adaptive-apps/guides/foldables/learn-about-foldables)、[Make your app fold aware](https://developer.android.com/develop/adaptive-apps/guides/foldables/make-your-app-fold-aware)、[`FoldingFeature`](https://developer.android.com/reference/kotlin/androidx/window/layout/FoldingFeature) | 铰链间隙、book / tabletop、`isSeparating` |

Tech Talk 里 Harry（UI Frameworks）对容器的定义：它坐在导航容器和内容容器之间，按规则摆放两个 view。规则的输入是水平与垂直 size class、宽高比，以及是否存在生效的 division。输出是每块内容出不出现，以及出现时的 frame。系统样式从 iOS 27.1 起提供，声明范围是 iOS、iPadOS 和 Mac Catalyst，不限于 iPhone Duo。SwiftUI 的 `.automatic` 解析成 split。

## 容器负责什么

调用方声明两块内容的角色和一种关系，容器决定当前环境下的可见性和 frame。

两种系统关系：

- **split**：两块内容互相不遮挡。对应原来的横向或纵向并排，例如正文和逐字稿、列表和详情。空间不够沿允许的轴切开时，只留 primary，secondary 暂时离开屏幕，状态仍保留。
- **overlay**：一块在前、一块在后。没有生效的分隔时，primary 叠在 secondary 之上，secondary 铺满容器。出现生效的分隔时，两块改到分隔两侧，不再重叠。

primary / secondary 的含义随关系变化，不能当成固定的“主内容 / 次内容”：

| | split | overlay |
| --- | --- | --- |
| primary | 空间不够时留下来的那一块；纵向切开时在分隔上方；横向切开时占布局比例 | 层叠时的前景。分隔生效后默认到 trailing 侧或下半 |
| secondary | 可以暂时消失的那一块；纵向切开时在分隔下方 | 层叠时铺满的背景。分隔生效后默认到 leading 侧或上半 |

Apple 自己的播放器示例在 split 和 overlay 之间切换时，会交换 `PlayerView` 和 `UpNextView` 谁当 primary。前景控件和“必须留下来的主内容”经常不是同一块。Flutter 侧不要在切换 style 时偷偷交换 child。角色由调用方写死。

容器不提供导航。列表进详情、返回栈、底栏和侧栏仍然放在它外面。需要可折叠栏目导航时，用应用自己的 `Navigator`，而不是把导航塞进 arrangement。

## 形态

下面的“书本”指分隔线竖直、左右两块可用区域；“桌面”指分隔线水平、上下两块可用区域。iPhone Duo 上这对应半折。Android 上还要加上第 7 节的铰链规则，摊平的物理铰链也算分隔。

### split

默认允许水平轴和垂直轴。容器比自己高更宽时优先水平切开，比自己宽更高时垂直切开，primary 在上。

| 环境 | 形态 |
| --- | --- |
| 无生效分隔，更宽 | 左右并排。primary 按比例占一块，另一块给 secondary |
| 无生效分隔，更高 | 上下叠放，中间不重叠。primary 在上，secondary 在下 |
| 书本，允许水平轴 | 左右各一块，分界落在折痕上。比例让位给折痕 |
| 桌面，允许垂直轴 | 上下各一块，分界落在折痕上。primary 在上 |
| 允许的轴切不开 | 只显示 primary。例如只允许水平轴、容器却更高；或只允许垂直轴、容器却更宽 |
| 合上、外屏、普通手机宽度 | 通常落在“只显示 primary”。外屏没有折痕可读 |

只允许一个轴是产品选择，不是降级：横向列表-详情用 `.split.axes(.horizontal)`，竖屏和桌面姿态就只留 primary；媒体在上、控件在下要留着垂直轴。

模拟器观察（不是文档保证）：书本姿态下 split 的分界贴着折痕，即使用了 `splitArrangementLayoutRatio`。宽屏上 `.split.axes(.vertical)` 会只剩 primary。

### overlay

| 环境 | 形态 |
| --- | --- |
| 无生效分隔（合上、完全展开的柔性屏、普通手机和平板） | 层叠。secondary 铺满。primary 浮在上面，模拟器里默认在 top-leading |
| 书本 | 左右分开。primary 默认在 trailing，secondary 在 leading |
| 桌面 | 上下分开。primary 默认在下半，secondary 在上半 |
| 调用方指定边缘 | `overlayArrangementEdge` 改的是分开之后 primary 所靠的边 |

层叠时，前景内容用紧凑形态；分开到自己的区域后用展开形态。SwiftUI 用 `overlayArrangementZIndex` 表达这件事：大于 0 表示这块还浮在背景上。内容闭包的根视图读到的始终是 0，要在子视图里读。这个值单独回答不了“已经左右分开”还是“我是底层”——分开之后也是 0。

HIG 允许在不需要 secondary 时把它收起。那是调用方的显隐，和“浮层变紧凑”不是同一件事。

### 一张图看两种关系

```text
无分隔、更宽          无分隔、更高           书本（竖折痕）        桌面（横折痕）

split
┌────┬────────┐      ┌────────────┐      ┌────┬──┬────────┐    ┌────────────┐
│ P  │   S    │      │     P      │      │ P  │缝│   S    │    │     P      │
│    │        │      ├────────────┤      │    │  │        │    ├────────────┤
│    │        │      │     S      │      │    │  │        │    │     缝     │
└────┴────────┘      └────────────┘      └────┴──┴────────┘    ├────────────┤
                                                                │     S      │
                                                                └────────────┘

overlay
┌────────────┐      ┌────────────┐      ┌────────┬──┬────┐    ┌────────────┐
│ S 铺满     │      │ S 铺满     │      │   S    │缝│ P  │    │     S      │
│  ┌──┐      │      │  ┌──┐      │      │        │  │    │    ├────────────┤
│  │P │ 浮层 │      │  │P │      │      │        │  │    │    │     缝     │
│  └──┘      │      │  └──┘      │      └────────┴──┴────┘    ├────────────┤
└────────────┘      └────────────┘                            │     P      │
                                                                └────────────┘
```

P 是 primary，S 是 secondary。overlay 在书本姿态下 P 默认靠 trailing（从左到右的界面里是右侧）。

### 尺寸是偏好，折痕是结果

这些修饰符写在子视图上，表达偏好，容器可以不照做：

| API | 作用 |
| --- | --- |
| `splitArrangementLayoutRatio` | primary 在并排时的比例。也有分轴的 min / ideal 形式 |
| `splitArrangementLayoutSize(minWidth:…)` | 一块内容的最小尺寸。达不到就不要硬挤成两栏 |
| `splitArrangementFixedLayoutSize(horizontal:vertical:)` | 固定尺寸偏好 |
| `overlayArrangementEdge` | 分隔生效、overlay 改成并排时，primary 靠哪一边 |
| `ArrangementViewStyle` | 自定义样式的协议。Flutter 第一版只做系统的 split 和 overlay |

生效的分隔存在时，分界用折痕的矩形，比例退居其次。没有分隔时才用比例。

容器不画分割线。它只分配两块 frame。柔性屏上的空白、物理铰链上的间隙，都是特征矩形本身，不是一条装饰。

## 子视图需要知道的结果

Apple 把结果拆成 `overlayArrangementZIndex`、`splitArrangementAxis` 和 reserved region。模拟器里 `splitArrangementAxis` 在测过的姿态下都是 `nil`。子视图要自己把这些碎片拼成“用户现在看见的是哪一种”。

Flutter 容器直接公布已经解析的呈现，避免每个 child 再推一遍：

| 呈现 | 含义 |
| --- | --- |
| `splitHorizontal` | 左右并排，给出轴和两块 frame |
| `splitVertical` | 上下并排，primary 在上 |
| `overlayLayered` | primary 浮在 secondary 上。浮层子树的 z-index 大于 0 |
| `overlaySeparated` | 由 overlay 关系产生的并排，两块都不重叠 |
| `primaryOnly` | 只摆了 primary。secondary 保持 State，不参与命中测试 |

z-index 仍提供，语义和 SwiftUI 对齐：只有浮层子树大于 0；内容根和已经分开的两侧都是 0。子视图用呈现枚举切换紧凑/展开，用 z-index 只处理“我是否还浮着”。

两块 child 在 `primaryOnly` 和层叠时都保留 State。重新出现时不要重建。frame 变化用动画，动画中两块的对应关系不变。

## UX 要点

这些规则来自 HIG 和 “Design for iPhone Duo”“Strike a pose”。容器要让遵守它们变得自然。

**按两种宽度设计，不按每种姿态各做一版。** 外屏是 compact width，内屏是 regular width。避免写死宽度、断点和某块屏幕的尺寸。桌面姿态可以让远处能看的内容在上、可点的控件在下，但控件和层级与其他姿态相同。合上再打开时，用户认得出是同一个界面。

**滚动内容穿过折痕，离散的可点元素躲开折痕。** 文章、信息流、文档、列表靠滚动适应，不要整段搬到折痕一侧。按钮、警告、菜单、弹出层、底部弹层要离开折痕：折痕上难点，也难看清。系统组件会自己挪；自定义控件要么放进 arrangement，要么自己读区域。能单独适应的元素单独挪，成组的元素一起挪。挪远了，和它的来源就失去关系。

**书本姿态把需要延续到外屏的内容放在 trailing。** 合上之后体验留在外屏，trailing 一侧离那次延续更近。警告走这条规则。overlay 的 primary 默认也在这一侧。

**桌面姿态上半用于远看，下半用于触摸。** 下半是稳的支撑面。split 把 primary 放在上半，所以远看的媒体当 primary、控件当 secondary。overlay 把 primary 放在下半，所以控件面板当 primary、画面当 secondary。两种关系的上下是反的。

**网格遇到折痕时用偶数栏。** 这是 reserved region 的用法，不是 arrangement 的形态。只要设备上存在 division（摊平、未生效也算），就倾向偶数栏，折痕落在栏间空隙。不要为了这件事去读铰链角度。

**安全区不对称。** 外屏和内屏横置时，导航和工具栏可以贴在一侧；分屏时另一侧也可能有对方应用的控制。inset 按每条边单独算。arrangement 的子树使用外层已经算好的 padding，不要假设左右对称。

**从左到右与从右到左。** leading / trailing 跟随 `Directionality`。折痕矩形是视图坐标里的物理区域，不因为书写方向再镜像一次。竖向系统栏贴硬件的那一侧，不跟书写方向对调；那部分不属于本容器。

**铰链角度不参与布局。** `onHingeChange` / `UIHingeInteraction` 的角度用于音高、视差这类效果。布局只看区域和这套规则。不要用角度阈值决定分栏。Android 上角度经常是 null，规则必须在没有角度时仍然完整。

**对话框、菜单、底部弹层不是 arrangement。** 它们是位移：整块挪到折痕的一侧，而不是拆成两栏。本 package 已有的约定保持不变：未生效、但仍有宽度的折痕不要写进 `MediaQuery.displayFeatures`，否则这些弹层会被切成半屏。

## 放在哪一层

```text
Navigator / Tab / NavigationRail     ← 导航在外
  └── Arrangement                    ← 两个区域
        ├── primary
        └── secondary
              └── List / Scroll      ← 滚动在内
```

- 导航容器包住 arrangement。arrangement 里面不再套一套导航分栏。
- arrangement 不要放进 `ListView`、`CustomScrollView`、`GridView`、`PageView`。它是屏幕上的两大块，不是一行。
- 一个页面一块 arrangement。里面可以再有普通的行、列、叠层。
- 模态路由由 `ArrangementScope` 之上的 Navigator 呈现，走 `MediaQuery` 里的生效特征做位移，不走本容器的两栏规则。

## Android 适配

Apple 的“完全展开 = 没有生效分隔”只适用于柔性屏折痕。Android 还有一种物理铰链：两块屏之间的间隙在摊平时仍然遮挡、仍然把窗口分成两块逻辑区域。Flutter 的 `DisplayFeature` 没有 `occlusionType` 和 `isSeparating`，用类型和姿态近似：

| 特征 | 是否作为分界 |
| --- | --- |
| `hinge`，不论 `postureFlat` 还是 `postureHalfOpened` | 是。矩形是碰不到的间隙，内容不要画进去 |
| `fold` + `postureHalfOpened` | 是。半折的柔性屏折痕 |
| `fold` + `postureFlat` | 否。不因此改成两栏。矩形特别厚时，可点元素离开它，可见性规则不变 |
| `cutout` | 否。摄像头和挖孔不是两栏的分界 |
| 矩形与容器不相交 | 忽略。分屏或自由窗口可能没盖住铰链 |

iOS 插件已经把“半折且生效、宽高都大于 0”的折痕放进 `displayFeatures`，摊平后的折痕留在 `inactiveDisplayFeatures`。容器只把 `displayFeatures` 里的 `fold` / `hinge` 当作候选分界，再套上表里的过滤。`inactiveDisplayFeatures` 可以用于“这是折叠设备，网格用偶数栏”，不能用于切开 arrangement，也不能写回 `MediaQuery`。

Android 引擎路径下，几何全部在 `displayFeatures` 里，`inactiveDisplayFeatures` 为空。摊平的 `hinge` 仍在这份列表中，所以上面的类型判断不能省。合上时应用窗口在外屏，这份列表里通常没有折痕；`HingePosture.closed` 是 iOS 读数，Android 第一版推不出 closed。外屏按“没有分隔的 compact 窗口”处理。

### 决策顺序

1. 找出与容器相交、且按上表应当作为分界的特征。竖直矩形要求水平分栏（左右），水平矩形要求垂直分栏（上下）。
2. 该轴在 style 的允许集合里，且分界两侧都能满足最小尺寸：两块内容贴着特征矩形的两侧摆放。split 在垂直分栏时 primary 在上；overlay 使用边缘偏好，默认 primary 在 trailing 或下半。比例不生效。
3. 该轴不在允许集合里：只显示 primary，并且 primary 的 frame 避开特征矩形，不横跨间隙。
4. 没有这样的特征时，才看宽高比。更宽且允许水平轴、两边都达到最小尺寸 → 水平 split 或保持 overlay 层叠（overlay 只在有分界时才分开）。更高且允许垂直轴、两边都达到最小尺寸 → split 上下，primary 在上；overlay 仍然层叠。
5. 其余情况：split 为 `primaryOnly`；overlay 为层叠。

第 4 步用最小尺寸，而不是再写一套 600dp / 840dp 断点。默认最小宽度要让外屏、普通手机竖屏、过窄的分屏落进单栏；内屏横置和大窗口可以两栏。半折或物理铰链走到第 2 步，不受这组宽度断点阻止——铰链两侧本来就是两块物理区域。

这和 Material 3 的 canonical layout 对齐的是几何，不是导航。`ListDetailPaneScaffold` 自带窗格返回栈；arrangement 不吸收这套栈。Android 上的底栏 / Navigation rail 留在容器外面，对应 iPhone Duo 上贴边的系统栏。

### 和 iPhone Duo 姿态的对应

| iPhone Duo | Android / Flutter | arrangement |
| --- | --- | --- |
| closed，外屏 | 另一块显示屏上的窗口，通常没有 fold/hinge | 无分隔。split 多半只留 primary；overlay 层叠 |
| partially open，书本 | `postureHalfOpened`，特征更高而窄 | 左右，间隙等于 `bounds` |
| partially open，桌面 | `postureHalfOpened`，特征更宽而矮 | 上下，间隙等于 `bounds` |
| fully open，柔性屏 | `fold` + `postureFlat`，iOS 上还会进 inactive | 当普通大窗口，用宽高比和最小尺寸 |
| fully open，双屏铰链 | `hinge` + `postureFlat`，间隙仍在 | 仍然绕开 `bounds`。允许的轴匹配时两栏，比例不覆盖间隙 |
| 角度 | iOS 有弧度；Android 常为 null | 不读 |

桌面姿态的上下和书本姿态的左右，都由特征矩形的方向决定，不由 `Orientation` 或 `userInterfaceIdiom` 决定。窗口可以在桌面窗口模式下被拖成任意比例，宽高比按容器自己的约束算，不按整块屏幕算。

物理铰链的 `occlusion` 是整段间隙都不可见、不可点。柔性半折更接近一条指导线，但半折时仍然要分开，因为姿态已经是 `postureHalfOpened`。两种都不要把按钮中心放进 `bounds`。

### 多窗口

特征必须和本容器的约束相交才生效。Android 自由窗口、分屏只占铰链一侧时，按没有分隔处理。iPhone Duo 内屏的系统分屏是另一件事：窗口变窄之后，若不再盖住折痕，同样退回宽高比规则。

合上与打开之间，留在屏幕上的那一块应当是外屏上用户会继续看到的内容。split 里这块是 primary。不要在 compact 时改成显示 secondary。

## 和现有代码的边界

`ArrangementController` / `ArrangementScope` 已经提供：

- `displayFeatures`：当前会影响布局、也会写入 `MediaQuery` 的特征。
- `inactiveDisplayFeatures`：设备上有，但不应切开屏幕的特征。
- `hinge`：`closed` / `partiallyOpen` / `fullyOpen` 和可选弧度。

arrangement 组件读取 scope，不自己再订阅平台。几何以 `DisplayFeature.bounds` 为准。`hinge.angle` 不进入布局函数；姿态只作为和特征对照的调试信息。引擎已经上报 fold 或 hinge 时，继续以引擎几何为准。

组件第一版不做的事：

- 用角度插值出中间 frame。
- 内置列表-详情的返回栈、侧边栏显隐按钮、系统分割线样式。
- 查询或避开摄像头遮挡。挖孔仍由 `SafeArea` 和 `MediaQuery` 处理。
- 竖向工具栏、外屏相机附件、多 scene。
- 把 inactive 折痕写回 `MediaQuery`。
- 为每种 Android 厂商姿势单独分支。帐篷、悬停如果系统报成 `postureHalfOpened` 加一个特征方向，就走同一套；报不出来就当没有分隔。

## Flutter API

容器叫 `ArrangementLayout`。尺寸偏好放在样式对象上，split 拿不到边，overlay 拿不到轴。

```dart
ArrangementLayout(
  style: const ArrangementStyle.split(
    axes: {Axis.horizontal},
    ratio: 0.4,
  ),
  primary: const InboxList(),
  secondary: const MessageDetail(),
)

ArrangementLayout(
  style: const ArrangementStyle.overlay(
    horizontalEdge: ArrangementEdge.trailing,
  ),
  primary: const PlayerControls(),
  secondary: const VideoSurface(),
)
```

`ArrangementStyle.automatic` 等于 split。`ratio` 省略时是 0.5，只在没有分界时生效。`minPrimaryExtent` 和 `minSecondaryExtent` 默认 320，沿分栏轴度量；某一侧达不到就不硬挤成两栏。宽大于等于高视为更宽。

overlay 没有最小尺寸。两侧都有正的空间就分开；某一侧没有空间时，在较大的一侧里层叠。层叠时 primary 用 `layeredConstraints`（默认最大宽度 400）测自然尺寸，再按 `layeredAlignment` 放进 `layeredPadding` 留出的区域。

子树读 `ArrangementPane.of(context)`。`presentation` 用来切换紧凑和展开，`isFloating`（`zIndex > 0`）只表示还浮在背景上。内容根上读到的就是真实 z-index，不像 SwiftUI 那样根视图始终读到 0。

`resolveArrangement` 和 `separatingFeatures` 是纯函数，测试和自定义容器可以直接调用。布局不读铰链角度，也不读 `inactiveDisplayFeatures`。

呈现变化时 frame 和透明度做动画，两块 child 不重建。只有尺寸变化（拖动窗口、旋转）时直接跳到新位置。分界区域留空，容器不画分割线。

特征矩形是视图全局坐标。容器可能在导航栏或 AppBar 下面，布局时换成自己的本地坐标；刚被移动的那一帧可能还用上一帧的原点。
