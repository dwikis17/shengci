nonisolated enum ChineseTextSegmentationMode:
  String,
  CaseIterable,
  Identifiable,
  Sendable
{
  case words = "Words"
  case characters = "Characters"

  var id: Self { self }
}
