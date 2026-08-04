import '../models/people_models.dart';

/// Pure permission rules for the People layer.
///
/// When no people exist the app behaves as before: full access, no gating.
/// Once at least one person exists, a signed-out state (`role == null`) has
/// no permissions — the router should already be showing `/login`.
bool canWriteFinancialData({required bool peopleEnabled, PersonRole? role}) {
  if (!peopleEnabled) return true;
  if (role == null) return false;
  return role != PersonRole.viewer;
}

bool canManagePeople({required bool peopleEnabled, PersonRole? role}) {
  if (!peopleEnabled) return true;
  if (role == null) return false;
  return role == PersonRole.admin;
}

bool canManageFireflyConnection({
  required bool peopleEnabled,
  PersonRole? role,
}) {
  if (!peopleEnabled) return true;
  if (role == null) return false;
  return role == PersonRole.admin;
}
