import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localization.dart';
import '../../core/services/user_service.dart';
import '../../core/utils/responsive.dart';

class WaVerificationScreen extends StatefulWidget {
  final String accessToken;
  final String? initialPhoneNumber;

  const WaVerificationScreen({
    super.key,
    required this.accessToken,
    this.initialPhoneNumber,
  });

  @override
  State<WaVerificationScreen> createState() => _WaVerificationScreenState();
}

class _WaVerificationScreenState extends State<WaVerificationScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String _currentPhone = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null &&
        widget.initialPhoneNumber!.isNotEmpty) {
      _phoneCtrl.text = widget.initialPhoneNumber!;
      _currentPhone = widget.initialPhoneNumber!;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOTP() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nomor minimal 10 digit'.tr(context))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _currentPhone = phone;
    });

    try {
      await UserService.requestPhoneOTP(widget.accessToken, phone);
      if (mounted) {
        setState(() {
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${'Kode OTP telah dikirim ke WhatsApp:'.tr(context)} $phone',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Gagal mengirim OTP:'.tr(context)} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await UserService.verifyPhoneOTP(widget.accessToken, _currentPhone, otp);

      await UserService.refreshCurrentUser(widget.accessToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nomor WhatsApp berhasil diverifikasi!'.tr(context)),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Gagal verifikasi OTP:'.tr(context)} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpCtrl.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1B3E);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Verifikasi WhatsApp'.tr(context),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.mark_chat_read_outlined,
                size: 80.w(context),
                color: Colors.green,
              ),
              SizedBox(height: 24.h(context)),
              Text(
                _otpSent
                    ? 'Masukkan Kode OTP'.tr(context)
                    : 'Kirim Kode Verifikasi'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp(context),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h(context)),
              Text(
                _otpSent
                    ? '${'Kode 6 digit telah dikirim ke:\n'.tr(context)}$_currentPhone'
                    : 'Masukkan nomor WhatsApp aktif Anda untuk menerima kode verifikasi OTP.'
                          .tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp(context),
                  color: textColor.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32.h(context)),

              if (!_otpSent) ...[
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Nomor WhatsApp'.tr(context),
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 24.h(context)),
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Kirim Kode OTP'.tr(context),
                          style: TextStyle(
                            fontSize: 16.sp(context),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ] else ...[
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.sp(context),
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.length == 6) {
                      _verifyOTP();
                    }
                  },
                ),
                SizedBox(height: 24.h(context)),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                SizedBox(height: 16.h(context)),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _otpCtrl.clear();
                          });
                        },
                  child: Text(
                    'Ubah Nomor / Kirim Ulang'.tr(context),
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
