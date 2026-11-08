#!/usr/bin/env python3
"""按映射把 /tmp/cap2 的新帧归档到 doc/screenshots（覆盖旧图）。"""
import os
import shutil

CAP = '/tmp/cap2'
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'doc/screenshots',
)

MAP = {
    # 浅色分类帧
    'gallery_home.png':                 'light/_home.png',
    'gallery_navigation.png':           'light/导航类_01.png',
    'gallery_navigation_bottom.png':    'light/导航类_05.png',
    'gallery_navigation_capsule.png':   'light/导航类_04.png',
    'gallery_navigation_floating.png':  'light/导航类_07.png',
    'gallery_navigation_minibar.png':   'light/导航类_09.png',
    'gallery_display.png':              'light/展示类_01.png',
    'gallery_action.png':               'light/操作类_v2/01.png',
    'gallery_input.png':                'light/输入类_v2/01.png',
    'gallery_selection.png':            'light/选择类_v2/01.png',
    'gallery_layout_grid.png':          'light/布局与动效_01.png',
    'gallery_layout_light.png':         'light/布局与动效_02.png',
    'gallery_layout_motion.png':        'light/布局与动效_03.png',
    'gallery_shared_element.png':       'light/布局与动效_05.png',
    'gallery_container.png':            'light/容器类_v2/01.png',
    'gallery_dialog.png':               'light/_dialog.png',
    'gallery_menu.png':                 'light/_menu.png',
    'gallery_popup.png':                'light/容器类_v3/07.png',
    'gallery_bottom_sheet.png':         'light/容器类_v3/08.png',
    'appbar_01_statusbar_band.png':     'light/导航类_03.png',
    'kit_02_pointlight_feathering.png': 'light/kit_v2/01.png',
    'kit_04_sidebar_submenu.png':       'light/kit_v2/02.png',
    'kit_05_rows_open.png':             'light/kit_v2/03.png',
    'kit_06_snackbar_resident.png':     'light/kit_v2/04.png',
    'kit_07_tabdiv_visible.png':        'light/kit_v2/05.png',
    'kit_08_picker_picked.png':         'light/kit_v2/06.png',
    'kit_09_blur_scrolled.png':         'light/kit_v2/07.png',
    'kit_10_actionbar.png':             'light/kit_v3/02.png',
    'kit_11_bottom_sections.png':       'light/kit_v3/03.png',
    'mag_01_indexer_drag.png':          'light/_mag1_try2.png',
    'mag_02_indexer_custom_bubble.png': 'light/_mag2_try2.png',
    'mag_03_magnifier_strip.png':       'light/_mag3_s2.png',
    # 深色
    'dark_01_home.png':                 'dark/_home.png',
    'dark_02_action.png':               'dark/操作类_01.png',
    'dark_03_selection.png':            'dark/选择类_01.png',
    'dark_04_input.png':                'dark/输入类_01.png',
    'dark_05_container.png':            'dark/容器类_01.png',
    'dark_06_menu.png':                 'dark/_menu3.png',
    'dark_07_ink_dark.png':             'ink/_home_inkdark.png',
    # 墨水屏
    'ink_01_home.png':                  'ink/_home.png',
    'ink_02_action.png':                'ink/操作类_01.png',
    'ink_03_selection.png':             'ink/选择类_01.png',
    'ink_04_dialog.png':                'ink/_dialog.png',
    'ink_05_popup.png':                 'ink/容器类_v3/06.png',
    'ink_06_bottom_sheet.png':          'ink/容器类_v3/07.png',
    'ink_07_input.png':                 'ink/输入类_01.png',
    'ink_08_container.png':             'ink/容器类_v2/01.png',
}

missing = [src for src in MAP.values() if not os.path.exists(os.path.join(CAP, src))]
if missing:
    print('MISSING SOURCES:')
    for m in missing:
        print(' ', m)
    raise SystemExit(1)

for dst, src in MAP.items():
    shutil.copyfile(os.path.join(CAP, src), os.path.join(OUT, dst))
print(f'copied {len(MAP)} files -> {OUT}')
