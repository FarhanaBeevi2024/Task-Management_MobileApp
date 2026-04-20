/// Kanban column keys — must match backend `issue.status`.
enum IssueStatus {
  toDo('to_do', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  inReview('in_review', 'In Review'),
  done('done', 'Completed');

  const IssueStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static IssueStatus fromApi(String? raw) {
    switch (raw?.trim()) {
      case 'in_progress':
        return IssueStatus.inProgress;
      case 'in_review':
        return IssueStatus.inReview;
      case 'done':
        return IssueStatus.done;
      case 'to_do':
      default:
        return IssueStatus.toDo;
    }
  }

  /// Next column in the default Kanban flow (for quick-advance swipe actions).
  IssueStatus? get nextKanbanStep {
    switch (this) {
      case IssueStatus.toDo:
        return IssueStatus.inProgress;
      case IssueStatus.inProgress:
        return IssueStatus.inReview;
      case IssueStatus.inReview:
        return IssueStatus.done;
      case IssueStatus.done:
        return null;
    }
  }

  /// Previous column in the default Kanban flow (for swipe "Back" actions).
  IssueStatus? get previousKanbanStep {
    switch (this) {
      case IssueStatus.toDo:
        return null;
      case IssueStatus.inProgress:
        return IssueStatus.toDo;
      case IssueStatus.inReview:
        return IssueStatus.inProgress;
      case IssueStatus.done:
        return IssueStatus.inReview;
    }
  }
}
