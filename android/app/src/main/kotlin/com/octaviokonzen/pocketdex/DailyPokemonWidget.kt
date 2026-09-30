package com.octaviokonzen.pocketdex

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

// Widget da tela inicial com o Pokémon do dia. O app guarda o nome e o
// sprite dos próximos 7 dias (lib/services/daily_widget.dart); aqui só
// escolhemos o de hoje (dia de Brasília, como no app e no site).
class DailyPokemonWidget : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    format.timeZone = TimeZone.getTimeZone("America/Sao_Paulo")
    val today = format.format(Date())
    val name = widgetData.getString("d_${today}_name", null)
    val image = widgetData.getString("d_${today}_img", null)

    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.daily_pokemon_widget)
      views.setTextViewText(R.id.widget_label, widgetData.getString("label", "Pokémon do dia"))
      views.setTextViewText(R.id.widget_name, name ?: "Abra o PocketDex")
      val bitmap = image?.let { BitmapFactory.decodeFile(it) }
      if (bitmap != null) {
        views.setImageViewBitmap(R.id.widget_sprite, bitmap)
      } else {
        views.setImageViewResource(R.id.widget_sprite, R.mipmap.ic_launcher)
      }
      views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}
