import 'hi/auth.dart';
import 'hi/patient_alerts.dart';
import 'hi/patient_care.dart';
import 'hi/patient_home.dart';
import 'hi/patient_me.dart';
import 'hi/staff.dart';

/// Every Hindi string, keyed by its English text.
final Map<String, String> hiStrings = {
  ...hiAuth,
  ...hiPatientHome,
  ...hiPatientAlerts,
  ...hiPatientCare,
  ...hiPatientMe,
  ...hiStaff,
};
