class AttendeeInput {
  String name;
  String ci;

  AttendeeInput({
    required this.name,
    required this.ci,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'ci': ci.trim(),
    };
  }

  factory AttendeeInput.empty() {
    return AttendeeInput(name: '', ci: '');
  }
}
