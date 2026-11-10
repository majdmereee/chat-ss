import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class ChatParser {
  static final RegExp _msgRegex = RegExp(
    r'^\[?[\u200e\u200f]?(\d{1,4}[\/\.\-]\d{1,2}[\/\.\-]\d{1,4})[،,\s]+([\d:]+)\s*([صمAPMapm]*)\]?\s*[-–:]\s*([^:]+):\s*(.*)$',
  );

  static List<ChatMessage> parse(String content, String mySenderName) {
    final List<ChatMessage> messages = [];
    final lines = content.split('\n');

    ChatMessage? lastMessage;

    for (var rawLine in lines) {
      final line = rawLine
          .replaceAll('\u200e', '')
          .replaceAll('\u200f', '')
          .replaceAll('\u202a', '')
          .replaceAll('\u202c', '')
          .trim();
      if (line.isEmpty) continue;

      final match = _msgRegex.firstMatch(line);
      if (match != null) {
        final datePart = match.group(1)!;
        final timePart = match.group(2)!;
        final amPmPart = match.group(3) ?? '';
        final sender = match.group(4)!.trim();
        final text = match.group(5)!.trim();

        DateTime? parsedDate = _parseDateTime(datePart, timePart, amPmPart);
        if (parsedDate != null) {
          final isMe = sender.toLowerCase().contains(mySenderName.toLowerCase()) || 
                       sender.toLowerCase().contains("majd");

          lastMessage = ChatMessage(
            sender: sender,
            message: text,
            originalTimestamp: parsedDate,
            isMe: isMe,
          );
          messages.add(lastMessage);
        }
      } else if (lastMessage != null) {
        final updatedText = "${lastMessage.message}\n$line";
        messages[messages.length - 1] = ChatMessage(
          id: lastMessage.id,
          sender: lastMessage.sender,
          message: updatedText,
          originalTimestamp: lastMessage.originalTimestamp,
          isMe: lastMessage.isMe,
        );
      }
    }
    return messages;
  }

  static DateTime? _parseDateTime(String date, String time, String amPm) {
    try {
      final cleanDate = date.replaceAll('‏', '').replaceAll('/', '-').replaceAll('.', '-');
      final cleanTime = time.replaceAll('‏', '');
      
      String period = '';
      if (amPm.contains('ص') || amPm.toUpperCase().contains('AM')) period = 'AM';
      if (amPm.contains('م') || amPm.toUpperCase().contains('PM')) period = 'PM';

      final fullString = "$cleanDate $cleanTime $period".trim();
      
      List<String> formats = [
        "d-M-yyyy h:m a",
        "d-M-yyyy h:m:s a",
        "yyyy-M-d h:m a",
        "yyyy-M-d h:m:s a",
        "d-M-yy h:m a",
        "d-M-yy h:m:s a",
        "d-M-yyyy HH:mm",
        "d-M-yyyy HH:mm:ss",
        "yyyy-M-d HH:mm",
        "yyyy-M-d HH:mm:ss",
      ];

      for (var f in formats) {
        try {
          return DateFormat(f).parseLoose(fullString);
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
}
