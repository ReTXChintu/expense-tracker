import '../models.dart';

enum SourceNoteMarker { sms, gmail, other }

class SourceNotePart {
  final SourceNoteMarker marker;
  final TxSource source;
  final String text;

  const SourceNotePart({
    required this.marker,
    required this.source,
    required this.text,
  });
}

/// Stores SMS + Gmail + overflow bodies in one DB `note` field using markers.
abstract final class TransactionSourceNotes {
  static const smsMarker = '[[SMS]]';
  static const gmailMarker = '[[GMAIL]]';
  static const otherMarker = '[[OTHER]]';

  static const _markerSpecs = [
    (smsMarker, SourceNoteMarker.sms, TxSource.sms),
    (gmailMarker, SourceNoteMarker.gmail, TxSource.gmail),
    (otherMarker, SourceNoteMarker.other, TxSource.manual),
  ];

  static List<SourceNotePart> parseParts(String? note, {required TxSource primary}) {
    if (note == null || note.isEmpty) return [];
    final hasMarker = _markerSpecs.any((m) => note.contains(m.$1));
    if (!hasMarker) {
      if (isPlaceholder(note)) return [];
      return [
        SourceNotePart(
          marker: SourceNoteMarker.other,
          source: primary,
          text: note.trim(),
        ),
      ];
    }

    final hits = <({int index, SourceNoteMarker marker, TxSource source})>[];
    for (final spec in _markerSpecs) {
      var start = 0;
      while (true) {
        final idx = note.indexOf(spec.$1, start);
        if (idx < 0) break;
        hits.add((index: idx, marker: spec.$2, source: spec.$3));
        start = idx + spec.$1.length;
      }
    }
    hits.sort((a, b) => a.index.compareTo(b.index));

    final parts = <SourceNotePart>[];
    for (var i = 0; i < hits.length; i++) {
      final hit = hits[i];
      final markerLen = _markerLength(hit.marker);
      final contentStart = hit.index + markerLen;
      final contentEnd = i + 1 < hits.length ? hits[i + 1].index : note.length;
      final text = note.substring(contentStart, contentEnd).trim();
      if (text.isNotEmpty && !isPlaceholder(text)) {
        parts.add(SourceNotePart(marker: hit.marker, source: hit.source, text: text));
      }
    }
    return parts;
  }

  static int _markerLength(SourceNoteMarker marker) => switch (marker) {
        SourceNoteMarker.sms => smsMarker.length,
        SourceNoteMarker.gmail => gmailMarker.length,
        SourceNoteMarker.other => otherMarker.length,
      };

  static Map<TxSource, String> parse(String? note, {required TxSource primary}) {
    final parts = parseParts(note, primary: primary);
    if (parts.isEmpty) return {};
    final out = <TxSource, String>{};
    for (final p in parts) {
      if (p.marker == SourceNoteMarker.sms) {
        out[TxSource.sms] = p.text;
      } else if (p.marker == SourceNoteMarker.gmail) {
        out[TxSource.gmail] = p.text;
      } else if (p.marker == SourceNoteMarker.other && p.source == TxSource.manual) {
        out[TxSource.manual] = p.text;
      } else {
        out[TxSource.manual] = p.text;
      }
    }
    return out;
  }

  static String encodeParts(List<SourceNotePart> parts) {
    final buf = StringBuffer();
    for (final p in parts) {
      final text = stripHtmlToPlain(p.text);
      if (text.isEmpty || isPlaceholder(text)) continue;
      final marker = switch (p.marker) {
        SourceNoteMarker.sms => smsMarker,
        SourceNoteMarker.gmail => gmailMarker,
        SourceNoteMarker.other => otherMarker,
      };
      buf.writeln(marker);
      buf.writeln(text);
    }
    return buf.toString().trim();
  }

  static String encode(Map<TxSource, String> parts) {
    final ordered = <SourceNotePart>[];
    if (parts[TxSource.sms]?.trim().isNotEmpty == true) {
      ordered.add(SourceNotePart(
        marker: SourceNoteMarker.sms,
        source: TxSource.sms,
        text: parts[TxSource.sms]!,
      ));
    }
    if (parts[TxSource.gmail]?.trim().isNotEmpty == true) {
      ordered.add(SourceNotePart(
        marker: SourceNoteMarker.gmail,
        source: TxSource.gmail,
        text: parts[TxSource.gmail]!,
      ));
    }
    if (parts[TxSource.manual]?.trim().isNotEmpty == true) {
      ordered.add(SourceNotePart(
        marker: SourceNoteMarker.other,
        source: TxSource.manual,
        text: parts[TxSource.manual]!,
      ));
    }
    return encodeParts(ordered);
  }

  static bool isSplittable(String? note, {required TxSource primary}) =>
      parseParts(note, primary: primary).length > 1;

  static List<TxSource> orderedSources(Map<TxSource, String> parts) {
    final list = <TxSource>[];
    if (parts[TxSource.sms]?.isNotEmpty == true) list.add(TxSource.sms);
    if (parts[TxSource.gmail]?.isNotEmpty == true) list.add(TxSource.gmail);
    if (parts[TxSource.manual]?.isNotEmpty == true) list.add(TxSource.manual);
    return list;
  }

  static List<TxSource> orderedSourcesFromParts(List<SourceNotePart> parts) =>
      parts.map((p) => p.source).toList();

  static final _placeholderRe = RegExp(
    r'^Auto-imported from (sms|email)$',
    caseSensitive: false,
  );

  static bool isPlaceholder(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return _placeholderRe.hasMatch(text.trim());
  }

  static String stripHtmlToPlain(String raw, {int maxLen = 2900}) {
    var plain = raw
        .replaceAll(
          RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length > maxLen) plain = plain.substring(0, maxLen);
    return plain;
  }

  static String? plainPreview(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final plain = stripHtmlToPlain(text);
    if (plain.isEmpty || isPlaceholder(plain)) return null;
    return plain;
  }

  static Map<TxSource, String> plainParts(Map<TxSource, String> parts) {
    final out = <TxSource, String>{};
    for (final e in parts.entries) {
      final plain = stripHtmlToPlain(e.value);
      if (plain.isNotEmpty && !isPlaceholder(plain)) {
        out[e.key] = plain;
      }
    }
    return out;
  }

  /// Combine note parts from two transactions, using OTHER for overflow slots.
  static List<SourceNotePart> mergeParts(
    List<SourceNotePart> a,
    List<SourceNotePart> b,
  ) {
    final out = <SourceNotePart>[...a];
    for (final p in b) {
      if (p.text.trim().isEmpty) continue;
      final slotTaken = out.any((e) => e.marker == p.marker && p.marker != SourceNoteMarker.other);
      if (slotTaken || p.marker == SourceNoteMarker.other) {
        out.add(SourceNotePart(
          marker: SourceNoteMarker.other,
          source: p.source,
          text: p.text,
        ));
      } else {
        out.add(p);
      }
    }
    return out;
  }
}
