/// Internal workflow labels — keep in sync with web `constants/workflowStatus.js`.
const String kDefaultWorkflowStatus = 'Dev In Progress';

const List<String> kWorkflowStatusesAll = [
  'Dev In Progress',
  'Dev Complete',
  'Released for UAT',
  'UAT In Progress',
  'UAT Complete',
  'Production Released',
  'Require Internal Clarification',
  'Waiting for Client Clarification',
];

const List<String> kWorkflowStatusesForInProgress = [
  'Dev In Progress',
  'Dev Complete',
  'Released for UAT',
  'UAT In Progress',
];

const List<String> kWorkflowStatusesForInReview = [
  'UAT Complete',
  'Production Released',
  'Require Internal Clarification',
  'Waiting for Client Clarification',
];

bool isWorkflowStatusEditableForBoard(String? boardStatusApi) {
  final s = (boardStatusApi ?? '').trim();
  return s == 'in_progress' || s == 'in_review';
}

List<String> workflowOptionsForBoard(String? boardStatusApi) {
  final s = (boardStatusApi ?? '').trim();
  if (s == 'in_progress') return List<String>.from(kWorkflowStatusesForInProgress);
  if (s == 'in_review') return List<String>.from(kWorkflowStatusesForInReview);
  return List<String>.from(kWorkflowStatusesAll);
}

String defaultWorkflowForBoardStatus(String? boardStatusApi) {
  final s = (boardStatusApi ?? '').trim();
  if (s == 'in_review') return kWorkflowStatusesForInReview.first;
  if (s == 'in_progress') return kWorkflowStatusesForInProgress.first;
  return kDefaultWorkflowStatus;
}

String normalizeWorkflowStatus(String? value, String? boardStatusApi) {
  final full = kWorkflowStatusesAll.toSet();
  final inProg = kWorkflowStatusesForInProgress.toSet();
  final inRev = kWorkflowStatusesForInReview.toSet();
  final str = (value ?? '').trim();
  if (str.isEmpty || !full.contains(str)) {
    return defaultWorkflowForBoardStatus(boardStatusApi);
  }
  final bs = (boardStatusApi ?? '').trim();
  if (bs == 'in_progress' && inProg.contains(str)) return str;
  if (bs == 'in_review' && inRev.contains(str)) return str;
  if (bs == 'in_progress') return kWorkflowStatusesForInProgress.first;
  if (bs == 'in_review') return kWorkflowStatusesForInReview.first;
  return str;
}
