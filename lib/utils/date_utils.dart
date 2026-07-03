String formatNullableDate(DateTime? value) {
  if (value == null) {
    return '未知时间';
  }
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
