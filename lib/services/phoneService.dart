import 'package:url_launcher/url_launcher.dart';

abstract class PhoneService {
  Future<void> makePhoneCall(String phoneNumber);
}

class RealPhoneService implements PhoneService {
  @override
  Future<void> makePhoneCall(String phoneNumber) async {
    phoneNumber = phoneNumber.replaceAll(' ', '').replaceAll('-', '');
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not launch phone dialer');
    }
  }
}
