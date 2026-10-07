/// Estimated one-rep-max math, matching FitNotes (the Brzycki formula).
class OneRm {
  OneRm._();

  /// Brzycki estimated 1RM: `weight * 36 / (37 - reps)`.
  /// Accurate for ~2–10 reps; reps are clamped to a sane range to avoid the
  /// asymptote at 37 reps.
  static double brzycki(double weight, int reps) {
    if (!weight.isFinite || weight <= 0 || reps <= 0 || reps >= 37) return 0;
    if (reps == 1) return weight;
    final r = reps >= 37 ? 36 : reps;
    return weight * 36 / (37 - r);
  }

  /// Inverse Brzycki: the weight expected for [reps] given a [oneRm].
  static double weightForReps(double oneRm, int reps) {
    if (reps <= 1) return oneRm;
    final r = reps >= 37 ? 36 : reps;
    return oneRm * (37 - r) / 36;
  }
}
