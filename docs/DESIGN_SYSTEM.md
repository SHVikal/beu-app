# BeU Design System

## Theme source of truth

All new UI must use [BeUTheme.swift](/Users/avikal/Documents/New%20project/ios/HealthDietCoach/HealthDietCoach/App/BeUTheme.swift).

Do not hardcode colors directly in views.

## Brand colors

- Background: `#FADADD`
- Card background: `#FFF5F7`
- Primary text: `#000000`
- Secondary text: `#333333`
- Muted/helper text: `#555555`
- Placeholder text: `#777777`
- Input background: `#000000`
- Input text: `#FFFFFF`
- Input placeholder: `#CCCCCC`
- Accent: `#FF8FAB`
- Border: black at `0.12` opacity

## Text color rules

- Page titles: `BeUTheme.primaryText`
- Section and card titles: `BeUTheme.primaryText`
- Body copy: `BeUTheme.secondaryText`
- Helper, disclaimer, and metadata copy: `BeUTheme.mutedText`
- Error text: `BeUTheme.lowStatus`
- Never use white text on pink or white cards
- Use white text only on black buttons or black inputs

## Fonts

- Title font: `BeUTheme.titleFont`
- Section title font: `BeUTheme.sectionTitleFont`
- Body font: `BeUTheme.bodyFont`
- Helper font: `BeUTheme.helperFont`
- Button font: `BeUTheme.buttonFont`

## Buttons

### Primary

- Background: black
- Text: white
- Use: `BeUPrimaryButtonStyle`

### Secondary

- Background: card background
- Border: `BeUTheme.border`
- Text: black
- Use: `BeUSecondaryButtonStyle`

## Inputs

- Use black input backgrounds with white text
- Placeholder text must be light gray and explicitly visible
- Use `beuInputFieldStyle()` for text entry controls
- Keep labels above or beside the field in `BeUTheme.secondaryText`

## Cards

- Use `BeUCard` for standard card containers
- Cards should use:
  - `BeUTheme.cardBackground`
  - subtle border
  - subtle shadow
  - readable black/dark text

## Pickers

- Do not rely on system default colors
- Segmented pickers should use a light color scheme and `BeUTheme.accent` tint
- Menu pickers should use black text
- Use `beuSegmentedControlStyle()` for segmented pickers
- Use `beuMenuPickerStyle()` for menu pickers

## Reusable components

- `BeUCard`
- `BeUPrimaryButtonStyle`
- `BeUSecondaryButtonStyle`
- `beuInputFieldStyle()`
- `beuSegmentedControlStyle()`
- `beuMenuPickerStyle()`
- `BeUSectionTitle`

## Profile feature patterns

- Profile gateway uses the same `BeUCard` treatment as dashboard cards.
- Safety disclaimers for supplements and health history use `BeUTheme.helperFont` and `BeUTheme.mutedText`.
- Health-history selection controls should use accent-filled states only for explicit selection, never for medical severity.
- Supplement active/paused states should change opacity, not color semantics that imply medical judgment.

## Correct usage examples

```swift
Text("Daily Nutrition")
    .font(BeUTheme.sectionTitleFont)
    .foregroundColor(BeUTheme.primaryText)

Text("These targets are estimates and can be adjusted anytime.")
    .font(BeUTheme.helperFont)
    .foregroundColor(BeUTheme.mutedText)

TextField("", text: $value)
    .beuInputFieldStyle()

Button("Save")
    .buttonStyle(BeUPrimaryButtonStyle())
```

## Rule for future work

All future components must use BeU theme tokens and reusable controls. Do not add ad hoc colors or rely on inherited text colors for visible UI. Hardcoded colors should be added to `BeUTheme` first, then reused from there.
