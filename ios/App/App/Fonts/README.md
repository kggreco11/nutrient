# Instrument Sans

Nutrient uses Instrument Sans for its semantic application typography. Native controls retain platform behavior; `NutrientType.font` preserves Dynamic Type scaling.

Source: [Instrument Sans in Google Fonts](https://github.com/google/fonts/tree/main/ofl/instrumentsans), retrieved 6 November 2026. Copyright 2022 The Instrument Sans Project Authors. The full SIL Open Font License is in InstrumentSans-OFL.txt.

The four bundled static TTF instances are derived from the upstream variable `InstrumentSans[wdth,wght].ttf` using fontTools varLib.instancer, fixing width at 100 and weight at 400/500/600/700. Name-table face names identify Regular, Medium, SemiBold and Bold, matching `NutrientType`. Font outlines are otherwise unchanged. Files are registered through UIAppFonts and copied with the Fonts resource folder. There is no runtime font download.

The local typography study compares Instrument Sans, Manrope and Public Sans at the same sizes and on the same nutrient/recipe content. Instrument Sans gives the chosen quiet layout a more distinct voice without relying on a display face. The design contract lives at `.interface-design/system.md`.
