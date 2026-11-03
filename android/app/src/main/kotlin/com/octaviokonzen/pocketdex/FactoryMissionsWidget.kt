package com.octaviokonzen.pocketdex

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

// Widget da tela inicial com as missões do dia do Pokelike. O app guarda o
// texto das missões dos próximos 7 dias e o progresso de hoje
// (lib/services/factory_widget.dart); aqui só escolhemos as de hoje (dia de
// Brasília, como no app e no site).
class FactoryMissionsWidget : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    format.timeZone = TimeZone.getTimeZone("America/Sao_Paulo")
    val today = format.format(Date())
    val texts = intArrayOf(R.id.mission_0_text, R.id.mission_1_text, R.id.mission_2_text)
    val progress = intArrayOf(R.id.mission_0_progress, R.id.mission_1_progress, R.id.mission_2_progress)
    val bars = intArrayOf(R.id.mission_0_bar, R.id.mission_1_bar, R.id.mission_2_bar)

    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.factory_missions_widget)
      views.setTextViewText(R.id.missions_title, widgetData.getString("title", "Missões de hoje"))
      for (k in 0 until 3) {
        val text = widgetData.getString("m_${today}_$k", null)
        if (text == null) {
          views.setTextViewText(texts[k], if (k == 0) widgetData.getString("empty", "Abra o PocketDex") else "")
          views.setTextViewText(progress[k], "")
          views.setProgressBar(bars[k], 100, 0, false)
          continue
        }
        val done = widgetData.getString("m_${today}_${k}_d", "0") == "1"
        val value = widgetData.getString("m_${today}_${k}_p", "0")?.toIntOrNull() ?: 0
        val goal = (widgetData.getString("m_${today}_${k}_n", "1")?.toIntOrNull() ?: 1).coerceAtLeast(1)
        val coins = widgetData.getString("m_${today}_${k}_c", "") ?: ""
        views.setTextViewText(texts[k], (if (done) "✅ " else "▫️ ") + text)
        views.setTextViewText(progress[k], "$value/$goal · $coins")
        views.setProgressBar(bars[k], 100, (value * 100 / goal).coerceIn(0, 100), false)
      }
      views.setOnClickPendingIntent(R.id.missions_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}
