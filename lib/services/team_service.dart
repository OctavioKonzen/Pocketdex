// lib/services/team_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/team.dart';

class TeamService {
  static const _teamsKey = 'pokemon_teams';
  final _uuid = const Uuid();

  Future<List<Team>> getTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final teamsString = prefs.getString(_teamsKey);
    if (teamsString == null) {
      return [];
    }
    final List<dynamic> teamsJson = json.decode(teamsString);
    return teamsJson.map((json) => Team.fromMap(json)).toList();
  }

  Future<void> _saveTeams(List<Team> teams) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> teamsJson =
        teams.map((team) => team.toMap()).toList();
    await prefs.setString(_teamsKey, json.encode(teamsJson));
  }

  Future<void> createTeam(String name) async {
    final teams = await getTeams();
    final newTeam = Team(id: _uuid.v4(), name: name);
    teams.add(newTeam);
    await _saveTeams(teams);
  }
  
  Future<void> updateTeam(Team updatedTeam) async {
    final teams = await getTeams();
    final index = teams.indexWhere((team) => team.id == updatedTeam.id);
    if (index != -1) {
      teams[index] = updatedTeam;
      await _saveTeams(teams);
    }
  }

  Future<void> deleteTeam(String teamId) async {
    final teams = await getTeams();
    teams.removeWhere((team) => team.id == teamId);
    await _saveTeams(teams);
  }
}