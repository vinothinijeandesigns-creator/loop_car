enum FieldType { text, phone, number, email, date, multiline }

class FormFieldConfig {
  final String label;
  final FieldType type;
  final bool required;
  final String? initialValue;
  final bool readOnly;

  const FormFieldConfig({
    required this.label,
    this.type = FieldType.text,
    this.required = true,
    this.initialValue,
    this.readOnly = false,
  });
}
