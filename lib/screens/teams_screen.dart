// lib/screens/teams_screen.dart

import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../widgets/team_card.dart';
import 'team_builder_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  late Future<List<Team>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  void _loadTeams() {
    setState(() {
      _teamsFuture = _teamService.getTeams();
    });
  }

  Future<void> _showCreateTeamPanel() async {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (builderContext) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(builderContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Criar Novo Time',
                    style: theme.textTheme.headlineSmall
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                        hintText: "Nome do Time",
                        hintStyle: TextStyle(color: theme.hintColor),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        )),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira um nome.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text('Cancelar',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 16)),
                        onPressed: () => Navigator.pop(builderContext),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF7786B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            )),
                        child: const Text('Criar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            await _teamService
                                .createTeam(nameController.text.trim());
                            
                            if (builderContext.mounted) {
                              Navigator.pop(builderContext);
                            }
                            _loadTeams();
                          }
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Team team) async {
    final theme = Theme.of(context);
    return showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Deletar Time', style: theme.textTheme.headlineSmall),
              content: Text(
                  'Tem certeza que deseja deletar o time "${team.name}"?',
                  style: theme.textTheme.bodyMedium),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancelar',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: const Text('Deletar',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await _teamService.deleteTeam(team.id);
                    if (dialogContext.mounted) {
                       Navigator.of(dialogContext).pop();
                    }
                    _loadTeams();
                  },
                ),
              ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Montador de Times'),
      ),
      body: FutureBuilder<List<Team>>(
        future: _teamsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Erro: ${snapshot.error}',
                    style: TextStyle(color: theme.colorScheme.error)));
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final teams = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return TeamCard(
                  team: team,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamBuilderScreen(team: team),
                      ),
                    );
                    _loadTeams();
                  },
                  onDelete: () => _confirmDelete(team),
                );
              },
            );
          } else {
            return Center(
              child: Text(
                'Você ainda não criou nenhum time.\nClique no botão "+" para começar!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTeamPanel,
        backgroundColor: const Color(0xFFF7786B),
        foregroundColor: Colors.white,
        tooltip: 'Criar Novo Time',
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}