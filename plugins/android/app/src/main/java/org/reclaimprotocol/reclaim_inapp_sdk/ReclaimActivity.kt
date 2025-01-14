package org.reclaimprotocol.reclaim_inapp_sdk

import android.content.Context
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

public class ReclaimActivity : FlutterActivity() {
    companion object {
        private const val engineId = "reclaim_flutter_engine"

//        private fun withCachedEngine(cachedEngineId: String): CachedEngineIntentBuilder? {
//            val engine = FlutterEngineCache
//                .getInstance()
//                .get(engineId)
//            if (engine == null) {
//                return null
//            }
//
//            return CachedEngineIntentBuilder(ReclaimActivity::class.java, cachedEngineId)
//        }

        private fun hasEngine(cachedEngineId: String): Boolean {
            return FlutterEngineCache
                .getInstance()
                .get(engineId) != null
        }

        private fun setupEngine(engine: FlutterEngine) {

            // Start executing Dart code to pre-warm the FlutterEngine.
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            // Cache the FlutterEngine to be used by FlutterActivity.
            FlutterEngineCache
                .getInstance()
                .put(engineId, engine)
        }

        public fun preWarm(context: Context) {
            if (hasEngine(engineId)) {
                return
            }
            // Instantiate a FlutterEngine.
            setupEngine(FlutterEngine(context))
        }

        public fun startActivity(context: Context) {
            var engine = withCachedEngine(engineId)
            if (engine == null) {
                preWarm(context)
                engine = withCachedEngine(engineId)!!
            }
            engine.build(context)
        }
    }
}