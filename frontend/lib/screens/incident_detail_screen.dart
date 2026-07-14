import 'package:flutter/material';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';

class IncidentDetailScreen extends StatelessWidget {
  final dynamic attempt;

  const IncidentDetailScreen({super.key, required this.attempt});

  Uint8List? _getPhotoBytes(String? base64String) {
    if (base64String == null || !base64String.startsWith('data:image')) return null;
    try {
      final base64Content = base64String.split(',')[1];
      return base64.decode(base64Content);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String method = attempt['method'] ?? 'unknown';
    final String result = attempt['result'] ?? 'unknown';
    final String timestampStr = attempt['timestamp'] ?? '';
    final String photoUrl = attempt['photoUrl'] ?? '';
    final Map<String, dynamic>? geo = attempt['geolocation'];

    final DateTime dateTime = DateTime.tryParse(timestampStr) ?? DateTime.now();
    final String formattedDate = '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    final bool isSuccess = result == 'success';
    final Uint8List? imageBytes = _getPhotoBytes(photoUrl);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      appBar: AppBar(
        title: Text('Incident Details', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Status Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFF3DDC97).withOpacity(0.08) : const Color(0xFFFF4D4D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSuccess ? const Color(0xFF3DDC97).withOpacity(0.2) : const Color(0xFFFF4D4D).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.warning,
                    color: isSuccess ? const Color(0xFF3DDC97) : const Color(0xFFFF4D4D),
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSuccess ? 'AUTHORIZED SHUTDOWN' : 'UNAUTHORIZED INTRUSION',
                          style: GoogleFonts.inter(
                            color: isSuccess ? const Color(0xFF3DDC97) : const Color(0xFFFF4D4D),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSuccess ? 'Identity Verified Successfully' : 'Bypass Lock Triggered',
                          style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Metadata card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Timestamp', formattedDate),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Verification Method', method.toUpperCase()),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow('Validation Result', result.toUpperCase()),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow(
                    'Device Location',
                    geo != null && geo['latitude'] != null 
                        ? 'Lat: ${geo['latitude']}, Lng: ${geo['longitude']}' 
                        : 'Not Available',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Intruder Photo Gallery Section (Only visible on failures)
            if (!isSuccess) ...[
              Text(
                'CAPTURED PHOTO',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF161C2C),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.no_photography_outlined, size: 48, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              'Privacy Disclosure: No photo recorded',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 32),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white10),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Dismiss Log', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (!isSuccess) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D4D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incident reported to security team.')),
                        );
                        Navigator.of(context).pop();
                      },
                      child: Text('Report Intruder', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
        Text(
          value,
          style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
