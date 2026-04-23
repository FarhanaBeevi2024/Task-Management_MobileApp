import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/permissions/session_permissions.dart';
import '../../../core/navigation/app_page_routes.dart';
import '../../projects/providers/projects_providers.dart';
import '../constants/workflow_status.dart';
import '../models/id_label_option.dart';
import '../models/issue_activity_log.dart';
import '../models/issue_model.dart';
import '../models/issue_status.dart';
import '../models/issue_type_model.dart';
import '../models/org_list_user.dart';
import '../providers/issues_providers.dart';
import 'issue_detail_screen.dart';

/// Full-screen form aligned with web `IssueForm` / `IssueDetail` fields.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.projectId,
    this.issue,
    this.initialParentIssueId,
  });

  final String projectId;

  /// When non-null, the form edits this issue; otherwise creates one in [projectId].
  final IssueModel? issue;

  /// When creating a new task, preselect this as the parent (subtask flow).
  final String? initialParentIssueId;

  bool get isEditing => issue != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _storyPointsController;
  late final TextEditingController _labelsController;
  late final TextEditingController _estimatedDaysController;
  late final TextEditingController _actualDaysController;

  IssueStatus _status = IssueStatus.toDo;
  List<IssueTypeModel> _types = [];
  String _typeId = '';
  bool _loadingTypes = false;
  bool _loadingAux = false;
  bool _saving = false;

  String _internalPriority = 'P3';
  String _clientPriority = '';
  String _assigneeId = '';
  String _releaseId = '';
  String _milestoneId = '';
  String _parentIssueId = '';
  bool _exposedToClient = false;
  String _workflowStatus = kDefaultWorkflowStatus;
  DateTime? _dueDate;

  List<OrgListUser> _users = [];
  List<IdLabelOption> _releases = [];
  List<IdLabelOption> _milestones = [];
  List<IssueModel> _projectIssues = [];
  List<IssueModel> _subtasks = [];
  bool _loadingSubtasks = false;

  static const int _titleMaxLength = 500;
  static const int _descriptionMaxLength = 8000;
  static const double _dropdownRadius = 10;

  /// Labels/values on the pastel gradient must not rely on [ColorScheme.onSurfaceVariant]
  /// alone (can read as white on some devices/themes).
  static const Color _labelOnPastelLight = Color(0xFF3D2F55);
  static const Color _valueOnPastelLight = Color(0xFF21152E);

  TextStyle _fieldLabelStyle(ColorScheme scheme, Brightness brightness) {
    final c = brightness == Brightness.dark ? scheme.onSurface.withValues(alpha: 0.9) : _labelOnPastelLight;
    return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: c, height: 1.15);
  }

  TextStyle _fieldValueStyle(ColorScheme scheme, Brightness brightness, {double fontSize = 13}) {
    final c = brightness == Brightness.dark ? scheme.onSurface : _valueOnPastelLight;
    return GoogleFonts.inter(fontSize: fontSize, color: c, height: 1.25);
  }

  static const _priorityChoices = [
    ('P1', 'P1 — Highest'),
    ('P2', 'P2 — High'),
    ('P3', 'P3 — Medium'),
    ('P4', 'P4 — Low'),
    ('P5', 'P5 — Lowest'),
  ];

  LinearGradient _formGradient(ColorScheme cs, Brightness b) {
    if (b == Brightness.dark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(cs.surface, cs.primary, 0.14)!,
          Color.lerp(cs.surface, cs.primary, 0.06)!,
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(cs.surface, cs.primary, 0.08)!,
        Color.lerp(cs.surface, cs.primary, 0.03)!,
      ],
    );
  }

  InputDecoration _compactDropdownDecoration(
    ColorScheme scheme,
    Brightness brightness, {
    required String label,
  }) {
    final ls = _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 11);
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: ls,
      floatingLabelStyle: ls,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_dropdownRadius),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_dropdownRadius),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.42)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_dropdownRadius),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.5),
      ),
    );
  }

  InputDecoration _descriptionDecoration(ColorScheme scheme, Brightness brightness) {
    const radius = BorderRadius.all(Radius.circular(12));
    final subtle = scheme.outlineVariant.withValues(alpha: 0.42);
    final focus = scheme.primary.withValues(alpha: 0.62);
    final labelC = brightness == Brightness.dark ? scheme.onSurface.withValues(alpha: 0.88) : _labelOnPastelLight;
    final hintC = brightness == Brightness.dark ? scheme.onSurfaceVariant : _labelOnPastelLight.withValues(alpha: 0.75);
    return InputDecoration(
      labelText: 'Description',
      labelStyle: GoogleFonts.inter(color: labelC, fontWeight: FontWeight.w600),
      floatingLabelStyle: GoogleFonts.inter(color: labelC, fontWeight: FontWeight.w600),
      hintText: 'Optional details, acceptance criteria…',
      hintStyle: GoogleFonts.inter(color: hintC),
      alignLabelWithHint: true,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: subtle)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: subtle)),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: focus, width: 1.75),
      ),
    );
  }

  String _normPriority(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    const map = {'highest': 'P1', 'high': 'P2', 'medium': 'P3', 'low': 'P4', 'lowest': 'P5', 'exposed_to_client': 'P3'};
    if (map.containsKey(s)) return map[s]!;
    if (s.startsWith('p') && s.length <= 3) return s.toUpperCase();
    return 'P3';
  }

  @override
  void initState() {
    super.initState();
    final i = widget.issue;
    _titleController = TextEditingController(text: i?.summary ?? '');
    _descriptionController = TextEditingController(text: i?.description ?? '');
    _storyPointsController = TextEditingController(text: i?.storyPoints?.toString() ?? '');
    _labelsController = TextEditingController(text: i != null && i.labels.isNotEmpty ? i.labels.join(', ') : '');
    _estimatedDaysController = TextEditingController(text: i?.estimatedDays?.toString() ?? '');
    _actualDaysController = TextEditingController(text: i?.actualDays?.toString() ?? '');

    if (i != null) {
      _status = i.status;
      _internalPriority = _normPriority(i.internalPriority);
      _clientPriority = i.clientPriority ?? '';
      _assigneeId = i.assigneeId ?? '';
      _milestoneId = i.milestoneId ?? '';
      _releaseId = i.releaseId ?? '';
      _parentIssueId = i.parentIssueId ?? '';
      _exposedToClient = i.exposedToClient;
      _dueDate = i.dueDate;
      _workflowStatus = normalizeWorkflowStatus(i.workflowStatus, i.status.apiValue);
    }
    if (i == null && (widget.initialParentIssueId ?? '').trim().isNotEmpty) {
      _parentIssueId = widget.initialParentIssueId!.trim();
    }

    if (!widget.isEditing) {
      _loadingTypes = true;
      Future<void>.microtask(_loadIssueTypes);
    }
    Future<void>.microtask(_loadAuxiliaryData);
    if (widget.isEditing && i != null) {
      Future<void>.microtask(_loadSubtasks);
    }
  }

  Future<void> _loadSubtasks() async {
    final parent = widget.issue?.id ?? '';
    if (parent.isEmpty) return;
    setState(() => _loadingSubtasks = true);
    try {
      final api = ref.read(issuesApiProvider);
      final list = await api.fetchIssues(
        projectId: widget.projectId,
        parentIssueId: parent,
      );
      if (!mounted) return;
      setState(() {
        _subtasks = list;
        _loadingSubtasks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSubtasks = false);
    }
  }

  Future<void> _loadIssueTypes() async {
    try {
      final api = ref.read(issuesApiProvider);
      final types = await api.fetchIssueTypes();
      if (!mounted) return;
      setState(() {
        _types = types;
        _typeId = types.isNotEmpty ? types.first.id : '';
        _loadingTypes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTypes = false);
    }
  }

  Future<void> _loadAuxiliaryData() async {
    setState(() => _loadingAux = true);
    final perms = await ref.read(sessionPermissionsProvider.future);
    final api = ref.read(issuesApiProvider);
    try {
      final users =
          perms.project.canAssignIssuesToOthers ? await api.fetchOrgUsers() : <OrgListUser>[];
      List<IdLabelOption> releases = [];
      List<IdLabelOption> milestones = [];
      List<IssueModel> issues = [];
      try {
        releases = await api.fetchActiveReleases(widget.projectId);
      } catch (_) {}
      try {
        milestones = await api.fetchProjectMilestones(widget.projectId);
      } catch (_) {}
      try {
        issues = await api.fetchIssues(projectId: widget.projectId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _users = users;
        _releases = releases;
        _milestones = milestones;
        _projectIssues = issues;
        _loadingAux = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAux = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _storyPointsController.dispose();
    _labelsController.dispose();
    _estimatedDaysController.dispose();
    _actualDaysController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Enter a title';
    if (t.length > _titleMaxLength) {
      return 'Title must be at most $_titleMaxLength characters';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final t = value ?? '';
    if (t.length > _descriptionMaxLength) {
      return 'Description must be at most $_descriptionMaxLength characters';
    }
    return null;
  }

  int? _parseOptionalInt(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  List<String> _parseLabels(String text) {
    return text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  String? _dueDateApiString() {
    final d = _dueDate;
    if (d == null) return null;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isProjectClient() {
    final projects = ref.read(projectsListProvider).valueOrNull;
    if (projects == null) return false;
    for (final p in projects) {
      if (p.id == widget.projectId) {
        return (p.currentUserProjectRole ?? '').toLowerCase().trim() == 'client';
      }
    }
    return false;
  }

  bool _showWorkflowField() {
    if (_isProjectClient()) return false;
    // Web shows workflow status for regular users; clients must not see it.
    return true;
  }

  /// Matches web `IssueForm`: assignee picker only when `canAssignIssuesToOthers`.
  String? _assigneeIdForSave(SessionPermissions perms) {
    if (!perms.project.canAssignIssuesToOthers) {
      if (widget.isEditing && widget.issue != null) {
        final id = widget.issue!.assigneeId?.trim();
        return (id == null || id.isEmpty) ? null : id;
      }
      return null;
    }
    final id = _assigneeId.trim();
    return id.isEmpty ? null : id;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 8),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!widget.isEditing) {
      if (_typeId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task types could not be loaded. Try again.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final api = ref.read(issuesApiProvider);
    final perms = await ref.read(sessionPermissionsProvider.future);
    final assigneeForApi = _assigneeIdForSave(perms);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final storyPts = _parseOptionalInt(_storyPointsController.text);
    final est = _parseOptionalInt(_estimatedDaysController.text);
    final act = _parseOptionalInt(_actualDaysController.text);
    final labels = _parseLabels(_labelsController.text);
    final dueStr = _dueDateApiString();
    final wf = _showWorkflowField() ? _workflowStatus : null;

    try {
      final IssueModel saved;
      if (widget.isEditing) {
        saved = await api.updateIssue(
          issueId: widget.issue!.id,
          summary: title,
          description: description.isEmpty ? null : description,
          statusApiValue: _status.apiValue,
          internalPriority: _internalPriority,
          clientPriority: _clientPriority,
          storyPoints: storyPts,
          labels: labels,
          dueDateYyyyMmDd: dueStr,
          estimatedDays: est,
          actualDays: act,
          exposedToClient: _exposedToClient,
          assigneeId: assigneeForApi,
          milestoneId: _milestoneId,
          workflowStatus: wf,
        );
      } else {
        saved = await api.createIssue(
          projectId: widget.projectId,
          issueTypeId: _typeId,
          summary: title,
          description: description.isEmpty ? null : description,
          status: _status.apiValue,
          internalPriority: _internalPriority,
          clientPriority: _clientPriority.isEmpty ? null : _clientPriority,
          assigneeId: assigneeForApi,
          releaseId: _releaseId.isEmpty ? null : _releaseId,
          milestoneId: _milestoneId.isEmpty ? null : _milestoneId,
          parentIssueId: _parentIssueId.isEmpty ? null : _parentIssueId,
          storyPoints: storyPts,
          labels: labels,
          estimatedDays: est,
          actualDays: act,
          exposedToClient: _exposedToClient,
          dueDateYyyyMmDd: dueStr,
          workflowStatus: wf,
        );
      }
      invalidateProjectTasksData(ref, widget.projectId);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(ColorScheme scheme, Brightness brightness, String text) {
    final c = brightness == Brightness.dark ? scheme.onSurface : _valueOnPastelLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final isBusy = _saving || (!widget.isEditing && _loadingTypes);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final bottomScrollPad = bottomInset + viewInsets + 24;
    final gradient = _formGradient(scheme, brightness);

    final parentCandidates = _projectIssues
        .where((x) => x.id != widget.issue?.id && (x.parentIssueId == null || x.parentIssueId!.isEmpty))
        .toList();

    final canAssignOthers = ref.watch(sessionPermissionsProvider).maybeWhen(
          data: (p) => p.project.canAssignIssuesToOthers,
          orElse: () => false,
        );

    final activityAsync = (widget.isEditing && widget.issue != null)
        ? ref.watch(issueActivityLogsProvider(widget.issue!.id))
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: scheme.inverseSurface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onInverseSurface,
        iconTheme: IconThemeData(color: scheme.onInverseSurface),
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onInverseSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        title: Text(
          widget.isEditing ? 'Edit task' : 'New task',
          style: GoogleFonts.inter(
            color: scheme.onInverseSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(18, 6, 18, bottomScrollPad),
                  children: [
                    Text(
                      widget.isEditing
                          ? 'Update the details below.'
                          : 'Add a task to this project.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: brightness == Brightness.dark
                            ? scheme.onSurface
                            : scheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!widget.isEditing) ...[
                      if (_loadingTypes)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_types.isEmpty)
                        Text(
                          'No task types available. Check your connection or permissions.',
                          style: GoogleFonts.inter(color: scheme.error, fontSize: 13),
                        )
                      else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _types.length > 1
                                  ? DropdownButtonFormField<String>(
                                      value: _typeId.isEmpty ? null : _typeId,
                                      isExpanded: true,
                                      decoration: _compactDropdownDecoration(scheme, brightness, label: 'Task type'),
                                      style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                                      dropdownColor: scheme.surface,
                                      items: _types
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t.id,
                                              child: Text(t.name, overflow: TextOverflow.ellipsis),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: isBusy ? null : (v) => setState(() => _typeId = v ?? ''),
                                    )
                                  : InputDecorator(
                                      decoration: _compactDropdownDecoration(scheme, brightness, label: 'Task type'),
                                      child: Text(
                                        _types.first.name,
                                        style: _fieldValueStyle(scheme, brightness, fontSize: 12)
                                            .copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<IssueStatus>(
                                value: _status,
                                isExpanded: true,
                                decoration: _compactDropdownDecoration(scheme, brightness, label: 'Status'),
                                style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                                dropdownColor: scheme.surface,
                                items: IssueStatus.values
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s.label, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                onChanged: isBusy
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _status = v;
                                          _workflowStatus = normalizeWorkflowStatus(_workflowStatus, v.apiValue);
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    if (widget.isEditing) ...[
                      DropdownButtonFormField<IssueStatus>(
                        value: _status,
                        isExpanded: true,
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Status'),
                        style: _fieldValueStyle(scheme, brightness, fontSize: 13),
                        dropdownColor: scheme.surface,
                        items: IssueStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: isBusy
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() {
                                  _status = v;
                                  _workflowStatus = normalizeWorkflowStatus(_workflowStatus, v.apiValue);
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _sectionTitle(scheme, brightness, 'Priorities'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _internalPriority,
                            decoration: _compactDropdownDecoration(scheme, brightness, label: 'Internal priority'),
                            style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                            dropdownColor: scheme.surface,
                            items: _priorityChoices
                                .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                                .toList(),
                            onChanged: isBusy ? null : (v) => setState(() => _internalPriority = v ?? 'P3'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _clientPriority.isEmpty ? null : _clientPriority,
                            decoration: _compactDropdownDecoration(scheme, brightness, label: 'Client priority'),
                            style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                            dropdownColor: scheme.surface,
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('Not set')),
                              ..._priorityChoices.map(
                                (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                              ),
                            ],
                            onChanged: isBusy
                                ? null
                                : (v) => setState(() => _clientPriority = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: scheme.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      child: SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        title: Text(
                          'Exposed to client',
                          style: _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 13),
                        ),
                        value: _exposedToClient,
                        onChanged: isBusy ? null : (v) => setState(() => _exposedToClient = v),
                      ),
                    ),
                    if (_showWorkflowField()) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: workflowOptionsForBoard(_status.apiValue).contains(_workflowStatus)
                            ? _workflowStatus
                            : workflowOptionsForBoard(_status.apiValue).first,
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Workflow status'),
                        style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                        dropdownColor: scheme.surface,
                        items: workflowOptionsForBoard(_status.apiValue)
                            .map((w) => DropdownMenuItem(value: w, child: Text(w, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: isBusy
                            ? null
                            : (v) {
                                if (v != null) setState(() => _workflowStatus = v);
                              },
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      enabled: !isBusy,
                      style: _fieldValueStyle(scheme, brightness, fontSize: 15),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Summary',
                        hintText: 'What needs to be done?',
                        labelStyle: _fieldLabelStyle(scheme, brightness),
                        floatingLabelStyle: _fieldLabelStyle(scheme, brightness),
                        hintStyle: GoogleFonts.inter(
                          color: brightness == Brightness.dark
                              ? scheme.onSurfaceVariant
                              : _labelOnPastelLight.withValues(alpha: 0.65),
                        ),
                        counterStyle: GoogleFonts.inter(
                          fontSize: 11,
                          color: brightness == Brightness.dark ? scheme.onSurfaceVariant : _labelOnPastelLight,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      maxLength: _titleMaxLength,
                      maxLines: 2,
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(scheme, brightness, 'Schedule & effort'),
                    InkWell(
                      onTap: isBusy ? null : _pickDueDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Due date').copyWith(
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: brightness == Brightness.dark ? scheme.primary : _labelOnPastelLight,
                          ),
                        ),
                        child: Text(
                          _dueDate == null
                              ? 'Tap to choose date'
                              : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
                          style: _dueDate == null
                              ? GoogleFonts.inter(
                                  fontSize: 13,
                                  color: brightness == Brightness.dark
                                      ? scheme.onSurfaceVariant
                                      : _labelOnPastelLight.withValues(alpha: 0.72),
                                )
                              : _fieldValueStyle(scheme, brightness, fontSize: 13),
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isBusy ? null : () => setState(() => _dueDate = null),
                          child: Text(
                            'Clear due date',
                            style: _fieldLabelStyle(scheme, brightness).copyWith(
                              fontSize: 12,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _estimatedDaysController,
                            enabled: !isBusy,
                            style: _fieldValueStyle(scheme, brightness, fontSize: 14),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Planned (days)',
                              labelStyle: _fieldLabelStyle(scheme, brightness),
                              floatingLabelStyle: _fieldLabelStyle(scheme, brightness),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _actualDaysController,
                            enabled: !isBusy,
                            style: _fieldValueStyle(scheme, brightness, fontSize: 14),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Actual (days)',
                              labelStyle: _fieldLabelStyle(scheme, brightness),
                              floatingLabelStyle: _fieldLabelStyle(scheme, brightness),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle(scheme, brightness, 'People & planning'),
                    if (canAssignOthers && _users.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _assigneeId.isEmpty ? null : _assigneeId,
                        isExpanded: true,
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Assign to'),
                        style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                        dropdownColor: scheme.surface,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Unassigned')),
                          ..._users.map(
                            (u) => DropdownMenuItem(
                              value: u.userId,
                              child: Text(
                                u.role != null ? '${u.email} (${u.role})' : u.email,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: isBusy ? null : (v) => setState(() => _assigneeId = v ?? ''),
                      )
                    else if (canAssignOthers && !_loadingAux && _users.isEmpty)
                      Text(
                        'Assignee list unavailable for your role.',
                        style: _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 12),
                      ),
                    if (_releases.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _releaseId.isEmpty ? null : _releaseId,
                        isExpanded: true,
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Release'),
                        style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                        dropdownColor: scheme.surface,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('No release')),
                          ..._releases.map((r) => DropdownMenuItem(value: r.id, child: Text(r.label))),
                        ],
                        onChanged: isBusy ? null : (v) => setState(() => _releaseId = v ?? ''),
                      ),
                    ],
                    if (_milestones.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _milestoneId.isEmpty ? null : _milestoneId,
                        isExpanded: true,
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Milestone'),
                        style: _fieldValueStyle(scheme, brightness, fontSize: 12),
                        dropdownColor: scheme.surface,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('No milestone')),
                          ..._milestones.map((m) => DropdownMenuItem(value: m.id, child: Text(m.label))),
                        ],
                        onChanged: isBusy ? null : (v) => setState(() => _milestoneId = v ?? ''),
                      ),
                    ],
                    if (parentCandidates.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _parentIssueId.isEmpty ? null : _parentIssueId,
                        isExpanded: true,
                        decoration: _compactDropdownDecoration(scheme, brightness, label: 'Parent issue (subtasks)'),
                        style: _fieldValueStyle(scheme, brightness, fontSize: 11),
                        dropdownColor: scheme.surface,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('None (top-level)')),
                          ...parentCandidates.map(
                            (x) => DropdownMenuItem(
                              value: x.id,
                              child: Text(
                                '${x.issueKey ?? '—'} — ${x.summary}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: isBusy ? null : (v) => setState(() => _parentIssueId = v ?? ''),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _sectionTitle(scheme, brightness, 'Details'),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _storyPointsController,
                            enabled: !isBusy,
                            style: _fieldValueStyle(scheme, brightness, fontSize: 14),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Story points',
                              labelStyle: _fieldLabelStyle(scheme, brightness),
                              floatingLabelStyle: _fieldLabelStyle(scheme, brightness),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _labelsController,
                            enabled: !isBusy,
                            style: _fieldValueStyle(scheme, brightness, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Labels',
                              hintText: 'comma-separated',
                              labelStyle: _fieldLabelStyle(scheme, brightness),
                              floatingLabelStyle: _fieldLabelStyle(scheme, brightness),
                              hintStyle: GoogleFonts.inter(
                                color: brightness == Brightness.dark
                                    ? scheme.onSurfaceVariant
                                    : _labelOnPastelLight.withValues(alpha: 0.65),
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.isEditing) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _sectionTitle(scheme, brightness, 'Subtasks'),
                          ),
                          FutureBuilder<SessionPermissions>(
                            future: ref.read(sessionPermissionsProvider.future),
                            builder: (context, snap) {
                              final canCreate = snap.data?.project.canCreateIssues ?? false;
                              if (!canCreate || _isProjectClient()) return const SizedBox.shrink();
                              return TextButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        final parentId = widget.issue?.id ?? '';
                                        if (parentId.isEmpty) return;
                                        final created = await Navigator.of(context).push<IssueModel>(
                                          AppPageRoutes.fade(
                                            TaskFormScreen(
                                              projectId: widget.projectId,
                                              initialParentIssueId: parentId,
                                            ),
                                          ),
                                        );
                                        if (!mounted) return;
                                        if (created != null) {
                                          invalidateProjectTasksData(ref, widget.projectId);
                                          await _loadSubtasks();
                                        }
                                      },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add subtask'),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_loadingSubtasks)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_subtasks.isEmpty)
                        Text(
                          'No subtasks yet. Add one to break down this issue.',
                          style: _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 12),
                        )
                      else
                        Column(
                          children: _subtasks.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: scheme.surface.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    s.summary.isEmpty ? '(Untitled)' : s.summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _fieldValueStyle(scheme, brightness, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    '${s.issueKey ?? '—'} • ${s.status.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 11),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: isBusy
                                      ? null
                                      : () {
                                          Navigator.of(context).push<void>(
                                            AppPageRoutes.fadeSlide(
                                              IssueDetailScreen(issue: s),
                                            ),
                                          );
                                        },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                    if (widget.isEditing) ...[
                      const SizedBox(height: 18),
                      _sectionTitle(scheme, brightness, 'History'),
                      const SizedBox(height: 8),
                      if (activityAsync == null)
                        const SizedBox.shrink()
                      else
                        activityAsync.when(
                          data: (logs) {
                            if (logs.isEmpty) {
                              return Text(
                                'No activity recorded yet.',
                                style: _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 12),
                              );
                            }
                            return Column(
                              children: logs
                                  .map(
                                    (log) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _ActivityRow(
                                        log: log,
                                        labelStyle:
                                            _fieldLabelStyle(scheme, brightness).copyWith(fontSize: 11),
                                        valueStyle:
                                            _fieldValueStyle(scheme, brightness, fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          error: (e, _) => Text(
                            e.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : _save,
                        icon: _saving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Icon(
                                widget.isEditing ? Icons.save_rounded : Icons.add_task_rounded,
                                size: 22,
                              ),
                        label: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            _saving ? 'Saving…' : (widget.isEditing ? 'Save changes' : 'Create Task'),
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.log,
    required this.labelStyle,
    required this.valueStyle,
  });

  final IssueActivityLog log;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = log.performedByEmail;
    final initial = (email != null && email.isNotEmpty) ? email[0].toUpperCase() : '?';
    final suffix = log.displayDateSuffix;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: valueStyle.copyWith(height: 1.35),
              children: [
                TextSpan(text: log.displayMessage),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: ' – $suffix',
                    style: labelStyle.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
