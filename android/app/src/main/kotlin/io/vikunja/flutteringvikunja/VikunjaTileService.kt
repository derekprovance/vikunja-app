package io.vikunja.flutteringvikunja

import android.app.PendingIntent
import android.content.Intent
import android.service.quicksettings.TileService

const val INTENT_TYPE_ADD_TASK = "ADD_NEW_TASK"

class VikunjaTileService : TileService() {

    override fun onClick() {
        super.onClick()
        val addIntent = Intent(this, MainActivity::class.java)
        addIntent.action = Intent.ACTION_INSERT
        addIntent.type = INTENT_TYPE_ADD_TASK

        startActivityAndCollapse(
            PendingIntent.getActivity(
                this,
                0,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
    }
}