/// The kind of a toast; drives its tone color and badge icon.
enum SileoState {
  /// Operation succeeded.
  success,

  /// Operation in progress; never expands.
  loading,

  /// Operation failed.
  error,

  /// Needs attention.
  warning,

  /// Neutral information.
  info,

  /// Carries an action button.
  action,
}
