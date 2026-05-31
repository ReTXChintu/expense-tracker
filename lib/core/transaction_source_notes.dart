import '../models.dart';

/// Stores SMS + Gmail bodies in one DB `note` field using markers.
abstract final class TransactionSourceNotes {
  static const smsMarker = '[[SMS]]';
  static const gmailMarker = '[[GMAIL]]';

  static Map<TxSource, String> parse(String? note, {required TxSource primary}) {
    if (note == null || note.isEmpty) return {};
    if (!note.contains(smsMarker) && !note.contains(gmailMarker)) {
      return {primary: note};
    }
    final out = <TxSource, String>{};
    final smsIdx = note.indexOf(smsMarker);
    final gmailIdx = note.indexOf(gmailMarker);
    if (smsIdx >= 0) {
      final end = gmailIdx >= 0 && gmailIdx > smsIdx ? gmailIdx : note.length;
      out[TxSource.sms] = note
          .substring(smsIdx + smsMarker.length, end)
          .trim();
    }
    if (gmailIdx >= 0) {
      final end = note.length;
      final start = gmailIdx + gmailMarker.length;
      out[TxSource.gmail] = note.substring(start, end).trim();
    }
    return out;
  }

  static String encode(Map<TxSource, String> parts) {
    final buf = StringBuffer();
    final sms = parts[TxSource.sms]?.trim();
    final gmail = parts[TxSource.gmail]?.trim();
    if (sms != null && sms.isNotEmpty) {
      buf.writeln(smsMarker);
      buf.writeln(sms);
    }
    if (gmail != null && gmail.isNotEmpty) {
      buf.writeln(gmailMarker);
      buf.writeln(gmail);
    }
    return buf.toString().trim();
  }

  static List<TxSource> orderedSources(Map<TxSource, String> parts) {
    final list = <TxSource>[];
    if (parts[TxSource.sms]?.isNotEmpty == true) list.add(TxSource.sms);
    if (parts[TxSource.gmail]?.isNotEmpty == true) list.add(TxSource.gmail);
    if (parts[TxSource.manual]?.isNotEmpty == true) list.add(TxSource.manual);
    return list;
  }
}
