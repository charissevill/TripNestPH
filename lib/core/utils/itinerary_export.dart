import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/itinerary.dart';

/// Turns an [Itinerary] into a shareable text summary or a downloadable
/// PDF — backs the "Share" and "Download" actions on the itinerary screen.
class ItineraryExport {
  ItineraryExport._();

  static String buildShareText(Itinerary itinerary) {
    final buffer = StringBuffer()
      ..writeln('My ${itinerary.totalDays}-day TripNest PH itinerary: ${itinerary.destinationName}')
      ..writeln('${itinerary.travelers} traveler(s) · Estimated budget ₱${itinerary.totalBudget.toStringAsFixed(0)}')
      ..writeln();

    for (final day in itinerary.days) {
      buffer.writeln('Day ${day.dayNumber} — ${day.dateLabel}');
      for (final activity in day.activities) {
        buffer.writeln('  ${activity.time} · ${activity.title} (${activity.location})');
      }
      buffer.writeln();
    }

    if (itinerary.recommendedAccommodations.isNotEmpty) {
      buffer.writeln('Recommended accommodations:');
      for (final place in itinerary.recommendedAccommodations) {
        final rating = place.rating != null ? ' — ★ ${place.rating!.toStringAsFixed(1)}' : '';
        buffer.writeln('  • ${place.name}$rating');
      }
      buffer.writeln();
    }

    if (itinerary.travelTips.isNotEmpty) {
      buffer.writeln('Travel tips:');
      for (final tip in itinerary.travelTips) {
        buffer.writeln('  • $tip');
      }
    }

    buffer.writeln();
    buffer.write('Planned with TripNest PH.');
    return buffer.toString();
  }

  /// The PDF uses the built-in base-14 fonts (no bundled Unicode font), so
  /// any text going into it needs to stay within what those fonts can
  /// actually draw. Swaps the handful of typographic characters that AI-
  /// generated or hand-written copy tends to contain (em/en dashes, curly
  /// quotes, bullets, the peso sign) for plain-ASCII equivalents. The
  /// share-as-text path doesn't need this — that's rendered by whatever
  /// app receives it, with full Unicode support.
  static String _sanitizeForPdf(String text) {
    return text
        .replaceAll('₱', 'PHP ')
        .replaceAll(RegExp('[—–]'), '-')
        .replaceAll('•', '-')
        .replaceAll(RegExp('[’‘]'), "'")
        .replaceAll(RegExp('[“”]'), '"')
        .replaceAll('…', '...');
  }

  static Future<Uint8List> buildPdfBytes(Itinerary itinerary) async {
    String s(String text) => _sanitizeForPdf(text);

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(s(itinerary.destinationName), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${itinerary.totalDays} days - ${itinerary.travelers} traveler(s) - Estimated budget PHP ${itinerary.totalBudget.toStringAsFixed(0)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Budget Breakdown', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Category', 'Amount (PHP)'],
            data: itinerary.budgetBreakdown.map((b) => [s(b.label), b.amount.toStringAsFixed(0)]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          if (itinerary.recommendedAccommodations.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Recommended Accommodations', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final place in itinerary.recommendedAccommodations)
              pw.Text(
                '- ${s(place.name)}${place.rating != null ? ' (${place.rating!.toStringAsFixed(1)} stars)' : ''}',
                style: const pw.TextStyle(fontSize: 10),
              ),
          ],
          pw.SizedBox(height: 16),
          pw.Text('Day-by-Day Plan', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          for (final day in itinerary.days) ...[
            pw.SizedBox(height: 10),
            pw.Text('Day ${day.dayNumber} - ${s(day.dateLabel)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            for (final activity in day.activities)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, left: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(width: 60, child: pw.Text(s(activity.time), style: const pw.TextStyle(fontSize: 10))),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(s(activity.title), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text(s(activity.description), style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(s(activity.location), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (itinerary.travelTips.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Travel Tips', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final tip in itinerary.travelTips) pw.Text('- ${s(tip)}', style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 20),
          pw.Text('Planned with TripNest PH', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
    return document.save();
  }
}
