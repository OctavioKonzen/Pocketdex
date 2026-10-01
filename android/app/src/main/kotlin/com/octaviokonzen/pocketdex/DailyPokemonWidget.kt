package com.octaviokonzen.pocketdex

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
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
    // Quadros do sprite animado (o widget do Android não toca GIF).
    val frames = (0 until (widgetData.getString("d_${today}_frames", null)?.toIntOrNull() ?: 0)).mapNotNull { i ->
      widgetData.getString("d_${today}_f$i", null)?.let { BitmapFactory.decodeFile(it) }
    }

    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.daily_pokemon_widget)
      views.setTextViewText(R.id.widget_label, widgetData.getString("label", "Pokémon do dia"))
      views.setTextViewText(R.id.widget_name, name ?: "Abra o PocketDex")
      val bitmap = image?.let { BitmapFactory.decodeFile(it) }
      views.removeAllViews(R.id.widget_flipper)
      if (frames.isNotEmpty()) {
        for (frame in frames) {
          val view = RemoteViews(context.packageName, R.layout.daily_pokemon_widget_frame)
          view.setImageViewBitmap(R.id.widget_frame, frame)
          views.addView(R.id.widget_flipper, view)
        }
        views.setInt(R.id.widget_flipper, "setFlipInterval", widgetData.getString("d_${today}_ms", null)?.toIntOrNull() ?: 100)
        views.setViewVisibility(R.id.widget_flipper, View.VISIBLE)
        views.setViewVisibility(R.id.widget_sprite, View.GONE)
      } else if (bitmap != null) {
        views.setViewVisibility(R.id.widget_flipper, View.GONE)
        views.setViewVisibility(R.id.widget_sprite, View.VISIBLE)
        views.setImageViewBitmap(R.id.widget_sprite, bitmap)
      } else {
        views.setViewVisibility(R.id.widget_flipper, View.GONE)
        views.setViewVisibility(R.id.widget_sprite, View.VISIBLE)
        views.setImageViewResource(R.id.widget_sprite, R.mipmap.ic_launcher)
      }
      views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
      appWidgetManager.updateAppWidget(id, views)
    }
  }
}
