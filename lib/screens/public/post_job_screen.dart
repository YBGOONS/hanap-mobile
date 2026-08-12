import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../models/categories.dart';
import '../../models/job.dart';
import '../../theme/dashboard_theme.dart';

/// Client-only. With no `job` passed, this is the Create form — calls the
/// post_job RPC, which inserts the job and notifies every active, available
/// worker whose skills match the category. With a `job` passed (must still
/// be `status == 'open'` — enforced both by the RLS policy on the update
/// and by only ever being reachable from an open job's card), it becomes
/// the Edit form instead, updating that row directly. Pushed from the
/// Client Dashboard, so it uses the dashboard theme (not the dark/gold
/// public-site one) to match the screen it's launched from.
class PostJobScreen extends StatefulWidget {
  final Job? job;
  const PostJobScreen({super.key, this.job});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  late String _category = widget.job?.category ?? kCategories.first;
  late final _descriptionCtrl = TextEditingController(text: widget.job?.description ?? '');
  late final _budgetCtrl = TextEditingController(text: widget.job?.budget != null ? widget.job!.budget!.toStringAsFixed(0) : '');
  late final _locationCtrl = TextEditingController(text: widget.job?.location ?? '');
  late DateTime? _scheduledDate = widget.job?.scheduledDate;
  String? _error;
  bool _loading = false;

  bool get _isEditing => widget.job != null;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _budgetCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: DashboardColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _submit() async {
    if (_descriptionCtrl.text.trim().isEmpty) {
      setState(() => _error = "Please describe the job.");
      return;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      setState(() => _error = "Location is required.");
      return;
    }
    final budgetText = _budgetCtrl.text.trim();
    final budget = budgetText.isEmpty ? null : double.tryParse(budgetText);
    if (budgetText.isNotEmpty && budget == null) {
      setState(() => _error = "Budget must be a number.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await supabase.from('jobs').update({
          'category': _category,
          'description': _descriptionCtrl.text.trim(),
          'budget': budget,
          'location': _locationCtrl.text.trim(),
          'scheduled_date': _scheduledDate?.toIso8601String().split('T').first,
        }).eq('id', widget.job!.id);
      } else {
        await supabase.rpc('post_job', params: {
          'category': _category,
          'description': _descriptionCtrl.text.trim(),
          'budget': budget,
          'location': _locationCtrl.text.trim(),
          'scheduled_date': _scheduledDate?.toIso8601String().split('T').first,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: DashboardColors.primary),
        title: Text(_isEditing ? "Edit Job" : "Post a Job", style: DashboardText.heading(size: 18, color: Colors.black87)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Category", style: DashboardText.body(size: 13, weight: FontWeight.w600, color: DashboardColors.muted)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: DashboardText.body(size: 14, color: Colors.black87),
                decoration: dashboardInputDecoration(label: "Category"),
                items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: DashboardText.body(size: 14, color: Colors.black87)))).toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descriptionCtrl,
                style: DashboardText.body(size: 14, color: Colors.black87),
                maxLines: 4,
                onChanged: (_) => setState(() => _error = null),
                decoration: dashboardInputDecoration(label: "Description", hint: "What needs to be done?"),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _locationCtrl,
                style: DashboardText.body(size: 14, color: Colors.black87),
                onChanged: (_) => setState(() => _error = null),
                decoration: dashboardInputDecoration(label: "Location", hint: "City, Province"),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _budgetCtrl,
                style: DashboardText.body(size: 14, color: Colors.black87),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _error = null),
                decoration: dashboardInputDecoration(label: "Budget (optional)", hint: "₱"),
              ),
              const SizedBox(height: 16),

              Text("Scheduled Date (optional)", style: DashboardText.body(size: 13, weight: FontWeight.w600, color: DashboardColors.muted)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DashboardColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: DashboardColors.muted),
                      const SizedBox(width: 10),
                      Text(
                        _scheduledDate == null
                            ? "Choose a date"
                            : "${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')}",
                        style: DashboardText.body(size: 14, color: _scheduledDate == null ? DashboardColors.muted : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              if (_error != null) ...[
                Text(_error!, style: DashboardText.body(size: 12, color: const Color(0xFFC62828))),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DashboardColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? "Save Changes" : "Post Job", style: DashboardText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
