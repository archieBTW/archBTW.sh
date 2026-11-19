import 'package:archbtw_sh/pages/music/annotations/blubber_annotations.dart';
import 'package:archbtw_sh/pages/music/annotations/lifes_lemons_annotations.dart';
import 'package:archbtw_sh/pages/music/annotations/santas_cookies_annotations.dart';

/// Normalizes a track title or lyric line so annotation lookups remain resilient
/// against casing, extra spacing, or smart-quote differences.
String normalizeAnnotationKey(String input) {
  return input
      .trim()
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

/// A single Rap Genius-style breakdown for a lyric line.
class LyricAnnotation {
  final String summary;
  final List<String> tags;

  const LyricAnnotation({
    required this.summary,
    this.tags = const [],
  });
}

/// Track-level overview plus per-line annotations keyed by normalized line text.
class TrackBreakdown {
  final String overview;
  final List<String> tags;
  final Map<String, LyricAnnotation> lineAnnotations;

  const TrackBreakdown({
    required this.overview,
    this.tags = const [],
    this.lineAnnotations = const {},
  });

  LyricAnnotation? annotationForLine(String rawLine) {
    final key = normalizeAnnotationKey(rawLine);
    return lineAnnotations[key] ??
        lineAnnotations[key.replaceAll(RegExp(r'\.+$'), '')] ??
        lineAnnotations['$key.'];
  }
}

/// Identifies a clickable target inside the lyrics view (either a track title or a line).
enum AnnotatableTargetKind {
  track,
  line,
}

/// Flat navigable item representing either a track header or an individual lyric line.
class AnnotatableItem {
  final int index;
  final int trackIndex;
  final String trackTitle;
  final AnnotatableTargetKind kind;
  final String text;
  final int? lineNumber;
  final int totalLinesInTrack;

  const AnnotatableItem({
    required this.index,
    required this.trackIndex,
    required this.trackTitle,
    required this.kind,
    required this.text,
    this.lineNumber,
    required this.totalLinesInTrack,
  });
}

/// A single rendered row inside a parsed track (either a stanza break or a lyric line).
class ParsedLyricRow {
  final bool isStanzaBreak;
  final AnnotatableItem? item;

  const ParsedLyricRow.stanzaBreak()
      : isStanzaBreak = true,
        item = null;

  const ParsedLyricRow.line(this.item) : isStanzaBreak = false;
}

/// A parsed track section from raw album lyrics.
class ParsedLyricTrack {
  final int trackIndex;
  final String title;
  final AnnotatableItem headerItem;
  final List<ParsedLyricRow> rows;

  const ParsedLyricTrack({
    required this.trackIndex,
    required this.title,
    required this.headerItem,
    required this.rows,
  });

  int get lineCount => rows.where((r) => !r.isStanzaBreak).length;
}

/// Complete parsed lyrics document for an album.
class ParsedAlbumLyrics {
  final List<ParsedLyricTrack> tracks;
  final List<AnnotatableItem> allItems;

  const ParsedAlbumLyrics({
    required this.tracks,
    required this.allItems,
  });
}

/// Parses the `[track title]` delimited raw lyrics string into structured tracks
/// and clickable items while preserving stanza breaks.
ParsedAlbumLyrics parseAlbumLyrics(String rawLyrics) {
  final rawLines = rawLyrics.split('\n');

  final List<_RawTrackBuffer> rawTracks = [];
  _RawTrackBuffer? current;
  bool inDescriptionBlock = false;

  for (final line in rawLines) {
    final trimmed = line.trim();
    if (trimmed == '**') {
      inDescriptionBlock = !inDescriptionBlock;
      continue;
    }
    if (inDescriptionBlock) {
      continue;
    }

    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final title = trimmed.substring(1, trimmed.length - 1).trim();
      current = _RawTrackBuffer(title);
      rawTracks.add(current);
      continue;
    }

    if (current == null) {
      continue;
    }

    if (trimmed.isEmpty) {
      if (current.entries.isNotEmpty && current.entries.last != null) {
        current.entries.add(null);
      }
    } else {
      current.entries.add(trimmed);
    }
  }

  final List<ParsedLyricTrack> parsedTracks = [];
  final List<AnnotatableItem> allItems = [];

  for (int t = 0; t < rawTracks.length; t++) {
    final buffer = rawTracks[t];
    // Trim trailing stanza breaks inside a track.
    while (buffer.entries.isNotEmpty && buffer.entries.last == null) {
      buffer.entries.removeLast();
    }

    final int totalLines = buffer.entries.where((e) => e != null).length;

    final headerItem = AnnotatableItem(
      index: allItems.length,
      trackIndex: t,
      trackTitle: buffer.title,
      kind: AnnotatableTargetKind.track,
      text: buffer.title,
      totalLinesInTrack: totalLines,
    );
    allItems.add(headerItem);

    final List<ParsedLyricRow> rows = [];
    int lineNum = 0;
    for (final entry in buffer.entries) {
      if (entry == null) {
        rows.add(const ParsedLyricRow.stanzaBreak());
      } else {
        lineNum++;
        final item = AnnotatableItem(
          index: allItems.length,
          trackIndex: t,
          trackTitle: buffer.title,
          kind: AnnotatableTargetKind.line,
          text: entry,
          lineNumber: lineNum,
          totalLinesInTrack: totalLines,
        );
        allItems.add(item);
        rows.add(ParsedLyricRow.line(item));
      }
    }

    parsedTracks.add(
      ParsedLyricTrack(
        trackIndex: t,
        title: buffer.title,
        headerItem: headerItem,
        rows: rows,
      ),
    );
  }

  return ParsedAlbumLyrics(
    tracks: parsedTracks,
    allItems: allItems,
  );
}

class _RawTrackBuffer {
  final String title;
  final List<String?> entries = [];

  _RawTrackBuffer(this.title);
}

/// Registry of all album annotations keyed by normalized album title.
final Map<String, Map<String, TrackBreakdown>> _albumAnnotationsRegistry = {
  normalizeAnnotationKey("santa's cookies"): santasCookiesAnnotations,
  normalizeAnnotationKey('blubber'): blubberAnnotations,
  normalizeAnnotationKey("life's lemons"): lifesLemonsAnnotations,
};

/// Returns the [TrackBreakdown] for a given album and track title, if available.
TrackBreakdown? getTrackBreakdown(String albumTitle, String trackTitle) {
  final albumMap = _albumAnnotationsRegistry[normalizeAnnotationKey(albumTitle)];
  if (albumMap == null) return null;
  return albumMap[normalizeAnnotationKey(trackTitle)];
}

/// Returns the [LyricAnnotation] for a specific line within an album and track.
LyricAnnotation? getLineAnnotation(
  String albumTitle,
  String trackTitle,
  String line,
) {
  final track = getTrackBreakdown(albumTitle, trackTitle);
  return track?.annotationForLine(line);
}
