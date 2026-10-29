import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/screens/manager/managerComapny.dart';
import 'package:shiftsmart/screens/manager/managerCreateProject1.dart';
import 'package:shiftsmart/screens/manager/managerProjectview.dart';
import 'package:shiftsmart/screens/manager/managerSite.dart';
import 'package:shiftsmart/services/ProjectService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/search.dart';
import 'package:shiftsmart/models/Project.dart';

class Managerprojects extends StatefulWidget {
  const Managerprojects({super.key});

  @override
  State<Managerprojects> createState() => _Managerprojectstate();
}

class _Managerprojectstate extends State<Managerprojects> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  final ProjectService _projectService = ProjectService();
  List<Project> allProjects = [];
  List<Project> filteredProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    fetchProjects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey.currentState?.show(); // optional spinner
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await fetchProjects();

    // if you want to show current shift too
    setState(() => _isLoading = false);
  }

  Future<void> fetchProjects() async {
    final projects = await _projectService.fetchAllProjects();

    setState(() {
      allProjects = projects;
      filteredProjects = List.from(projects);
      _isLoading = false;
    });
  }

  void onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProjects = List.from(allProjects);
      } else {
        filteredProjects = allProjects.where((project) {
          bool matches =
              project.name.toLowerCase().contains(query.toLowerCase());
          print(
              "Checking: ${project.name} | Query: $query | Matches: $matches");
          return matches;
        }).toList();
      }
    });

    print("Filtered Projects: $filteredProjects");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Background(),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF724584)),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        key: _refreshKey,
                        onRefresh: _refreshData,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Search(onQueryChanged: onQueryChanged),
                              _createProject(),
                              _createSite(),
                              _createCompany(),
                              const SizedBox(height: 10),
                              Container(
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
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "PROJECTS LIST",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _taskList(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                )
        ],
      ),
    );
  }

  Widget _createProject() {
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
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(
            children: [
              Icon(
                Icons.edit_document,
                color: Color(0xFF3498DB),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                "CREATE PROJECT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const Managercreateproject()), // Replace with your page
              );
            },
            child: Icon(
              Icons.add_box_outlined,
              color: Colors.blueAccent,
              size: 32,
            ),
          ),
        ]));
  }

  Widget _createSite() {
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Row(
          children: [
            Icon(
              Icons.travel_explore,
              color: Color(0xFF3498DB),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              "CREATE SITE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Managersite()),
            );
          },
          child: Icon(
            Icons.add_box_outlined,
            color: Colors.blueAccent,
            size: 32,
          ),
        ),
      ]),
    );
  }

  Widget _createCompany() {
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Row(
          children: [
            Icon(
              Icons.business_outlined,
              color: Color(0xFF3498DB),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              "CREATE COMPANY",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Managercomapny()),
            );
          },
          child: Icon(
            Icons.add_box_outlined,
            color: Colors.blueAccent,
            size: 32,
          ),
        ),
      ]),
    );
  }

  Widget _taskList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        final project = filteredProjects[index];

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Managerprojectview(project: project),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.checklist_rtl,
                    color: Color(0xFF3498DB), size: 24),
                const SizedBox(width: 12),

                /// Project Info (Name + Due)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(project.projectDue))}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                /// Status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.status,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusIcon(project.status),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Icon(Icons.domain_verification_outlined,
            color: Colors.green, size: 20);
      case 'pending':
        return const Icon(Icons.hourglass_top, color: Colors.red, size: 20);
      case 'active':
      default:
        return Icon(Icons.donut_large_sharp,
            color: Colors.amberAccent, size: 20);
    }
  }
}
