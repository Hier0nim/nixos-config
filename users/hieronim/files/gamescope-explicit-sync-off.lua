function info(text)
    gamescope.log(gamescope.log_priority.info, text)
end

info("Disabling explicit sync: " .. tostring(gamescope.convars.drm_debug_disable_explicit_sync.value) .. " -> " .. tostring(true))
gamescope.convars.drm_debug_disable_explicit_sync.value = true
