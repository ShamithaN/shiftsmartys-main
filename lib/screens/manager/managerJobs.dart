import 'package:flutter/material.dart';
import 'package:shiftsmart/models/Job.dart';
import 'package:shiftsmart/screens/manager/managerAllShifts.dart';
import 'package:shiftsmart/screens/manager/managerCreateJob.dart';
import 'package:shiftsmart/screens/manager/managerJobView.dart';
import 'package:shiftsmart/services/JobService.dart';
import 'package:shiftsmart/services/ProjectService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/search.dart';
import 'package:shiftsmart/models/Project.dart' as model;

class Managerjobs extends StatefulWidget {
  const Managerjobs({super.key});

  @override
  State<Managerjobs> createState() => _ManagerjobsState();
}

class _ManagerjobsState extends State<Managerjobs>
    with AutomaticKeepAliveClientMixin {
  List<Job> allJobs = [];
  List<Job> filteredJobs = [];

  bool _isLoading = true;
  Map<int, model.Project> projectMap = {};


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _loadData();
  }

  String _formatDate(String dateTimeString) {
    if (dateTimeString.contains('T')) {
      return dateTimeString.split('T')[0];
    }
    return dateTimeString;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      //fetch projects from service
      final projects = await ProjectService().fetchAllProjects();
      setState(() {
        projectMap = {for (var p in projects) p.projectId: p};
      });

      //fetch jobs from service file
      final jobs = await JobService().fetchAllJobs();
      setState(() {
        allJobs = jobs;
        filteredJobs = List.from(jobs);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredJobs = List.from(allJobs);
      } else {
        filteredJobs = allJobs.where((job) {
          return job.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const SizedBox(height: 10),
                  Search(onQueryChanged: onQueryChanged),
                  _createJob(),
                  _createShift(),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "JOB LIST",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.58, // or adjust as needed
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF724584)))
                        : _jobList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _createShift() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(180, 42, 50, 67),
            Color.fromARGB(180, 34, 40, 52),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Image.asset('assets/cShift.png', height: 30),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    "CREATE SHIFT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Managerallshifts(),
                ),
              );
            },
            child: Icon(
              Icons.add_box_outlined,
              color: Colors.blueAccent,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobList() {
    if (filteredJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/cJob.png', height: 30),
            const SizedBox(height: 16),
            Text("No jobs found",
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            const SizedBox(height: 8),
            Text("Try again later",
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      );
    }

  

    return Gradienthorizontal(
      width: double.infinity,
      height:double.infinity,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        itemCount: filteredJobs.length,
        itemBuilder: (context, index) {
          final job = filteredJobs[index];
          return _buildStyledJobCard(job);
        },
      ),
    );
  }

  Widget _buildStyledJobCard(Job job) {
    return GestureDetector(
      onTap: () async {
        debugPrint("Tapped on job: ${job.title}");
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManagerJobView(job: job),
          ),
        );
        debugPrint("Returned from ManagerJobView");
        debugPrint("job runtimeType: ${job.runtimeType}");
        // debugPrint("job is Job: ${job is Job}");
        debugPrint("jobDueDate: ${job.jobDueDate}"); // Will crash if it's a Map

        if (result == true) {
          _loadData();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 13),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF363E51),
              Color(0xFF191E26),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Left icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Image.asset('assets/cJob.png', height: 30),
            ),
            const SizedBox(width: 12),

            // Job info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Due Date: ${job.jobDueDate.isNotEmpty ? _formatDate(job.jobDueDate) : 'No date'}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _createJob() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(180, 42, 50, 67),
            Color.fromARGB(180, 34, 40, 52),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Image.asset('assets/cJob.png', height: 30),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    "CREATE JOB",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManagerCreateJob(),
                ),
              );
            },
            child: Icon(
              Icons.add_box_outlined,
              color: Colors.blueAccent,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
