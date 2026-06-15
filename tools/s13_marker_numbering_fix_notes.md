# S13 marker numbering implementation note

Rule confirmed by supervisor:

- Same active/high-level rawIndex keeps one horizontal K position.
- If only one nested BSP trigger exists under that high-level K, show arrow only and no number.
- If multiple nested BSP triggers exist under the same high-level K, show numbers next to arrows: 1, 2, 3...
- Sequence is ordered by lower-level BSP rawIndex ascending within the active rawIndex group.
- Each numbered arrow must jump to its own lower-level BSP.
- Do not use horizontal offset as the primary presentation.
- Do not rely on popover as the primary presentation.

Required code change:

- Replace Set<int> activeAnchorRawIndexes with a trigger list so multiple lower-level BSPs are preserved.
- Add marker fields: sequenceNumber, sequenceTotal, sourceLevel, sourceRawIndex.
- Add row fields: isTriggerSource, sequenceLabel, isIntervalAnchor.
- Render sequenceLabel only when sequenceTotal > 1.
- Keep sequenceLabel null when sequenceTotal == 1.
