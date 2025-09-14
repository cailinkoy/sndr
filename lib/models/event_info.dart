import 'package:flutter_contacts/flutter_contacts.dart';

class EventInfo {
  final Contact contact;
  final Event event;
  final int daysLeft;

  EventInfo({
    required this.contact,
    required this.event,
    required this.daysLeft,
  });
}
