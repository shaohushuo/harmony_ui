# 设计规范配图索引

> 由 `tool/scan_ux_images.py` 生成，**不要手改**。原始图片在 `doc/reference/design/img/`（不入库，
> 用 `tool/fetch_ux_images.sh` 重新获取）。逐张精读的结论写 `doc/ux-specs/<slug>.md`，
> 三列对照见 `doc/UX-SPEC-FROM-IMAGES.md`。

- 图片总数 **608**
- 标注候选 **113**（判据：检出洋红标注色，见脚本 `is_annotation_candidate`）
- 非候选 **495**，其中大尺寸无标注色 **194** 张（抽样确认为形态示意，未逐张精读）

## 逐控件

| 控件 | 图数 | 标注候选 | 候选编号 | 段落标签 |
| --- | --- | --- | --- | --- |
| `alphabetindexer` | 13 | 2 | 12、13 | spacing、visual-rule、wearable |
| `badge` | 6 | 1 | 04 | — |
| `bindsheet` | 24 | 5 | 02、03、16、17、18 | motion、spacing、tablet |
| `blank` | 5 | 4 | 02、03、04、05 | — |
| `bottomtab` | 35 | 22 | 03、04、05、06、08、09、10、11、14、15、16、17、18、19、21、22、24、26、27、28、30、31 | color、motion、tablet |
| `button` | 45 | 13 | 26、28、30、31、32、34、35、38、39、42、43、44、45 | color、spacing、tablet、wearable |
| `checkbox` | 8 | 0 | — | typography |
| `chips` | 9 | 1 | 07 | visual-rule |
| `chipsgroup` | 12 | 0 | — | spacing、tablet |
| `color` | 11 | 10 | 02、03、04、05、06、07、08、09、10、11 | color、spacing、tablet |
| `component_actionbar` | 7 | 0 | — | shadow |
| `component_snackbar` | 12 | 0 | — | visual-rule |
| `counter` | 5 | 0 | — | — |
| `datapanel` | 14 | 2 | 10、11 | corner、spacing |
| `dialog` | 26 | 4 | 11、15、22、23 | corner、tablet、wearable |
| `divider` | 6 | 3 | 03、05、06 | — |
| `image` | 31 | 3 | 11、23、24 | — |
| `list` | 51 | 15 | 03、08、10、15、18、19、20、26、29、40、41、42、49、50、51 | — |
| `menu` | 12 | 1 | 12 | visual-rule |
| `patternlock` | 4 | 0 | — | color |
| `picker` | 22 | 1 | 11 | wearable |
| `popup` | 19 | 0 | — | tablet、visual-rule |
| `progress` | 5 | 1 | 02 | motion |
| `qrcode` | 10 | 0 | — | — |
| `radio` | 5 | 1 | 05 | — |
| `rating` | 3 | 0 | — | — |
| `scrollbar` | 10 | 3 | 04、09、10 | wearable |
| `search` | 21 | 1 | 15 | visual-rule |
| `segmentbutton` | 15 | 2 | 09、10 | corner、spacing、tablet |
| `select` | 11 | 3 | 02、03、04 | — |
| `slider` | 14 | 0 | — | visual-rule、wearable |
| `subheader` | 12 | 2 | 11、12 | spacing、visual-rule、wearable |
| `swiper` | 8 | 3 | 02、03、04 | wearable |
| `text` | 5 | 1 | 05 | — |
| `textclock` | 6 | 0 | — | — |
| `textinput` | 18 | 0 | — | color、corner、wearable |
| `textselection` | 8 | 0 | — | visual-rule |
| `titlebar` | 39 | 7 | 14、15、19、20、21、38、39 | color、tablet、typography、visual-rule、wearable |
| `toast` | 17 | 1 | 17 | spacing、tablet、visual-rule、wearable |
| `togglebutton` | 6 | 0 | — | visual-rule |
| `toggleswitch` | 9 | 1 | 09 | visual-rule、wearable |
| `toolbar` | 9 | 0 | — | tablet |
