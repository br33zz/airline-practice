{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loading = document.getElementById('app-loading');
    if (loading) loading.remove();
    performance.mark('airline-app-ready');
    window.dispatchEvent(new Event('airline-app-ready'));
  }
});
