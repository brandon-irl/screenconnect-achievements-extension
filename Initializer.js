SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
	switch (eventArgs.commandName) {
		case 'viewAchievements':
			//SC.dialog.showModalPage(SC.res['Achievements.AchievementText'],
			//	'Achievements.aspx',
			//	null
			//);

			SC.util.includeStyleSheet(extensionContext.baseUrl + 'Style.css');

			SC.service.GetAchievementDefinitions(function (result) {
				var achievementsPanel = $div({ className: 'AchievementsPanel' },
					result.Definition.map(
						function (def) {
							return $div({ className: 'Definition' },
								[
									$p(def.Title),
									$p(def.Description),
									$img({src: SC.ui.createDataUri(def.Image)})
								]
							);
						}
					)
				);

				SC.dialog.showModalButtonDialog(
					"Achievements",	// subClassName
					SC.res['Achievements.AchievementText'],	// title
					"ButtonText",	// buttonText
					"Close",		// buttonCommandName
					function (container) {	// contentBuilderProc
						SC.ui.setContents(
							container,
							[
								SC.ui.createElement('p', JSON.stringify(result)),
								achievementsPanel
							]
						);
					},
					null,	// onExecuteCommandProc
					null	//onQueryCommandButtonStateProc
				);
			});

			break;
	}
});

SC.event.addGlobalHandler(SC.event.PostRender, function () {
	var version = 0;
	var pendingRequest = null;
	var proc = function (version) {
		if (!SC.ui.isWindowActive()) {
			window.setTimeout(function () {
				proc(version);
			}, 1000);
		} else {
			pendingRequest = SC.service.GetAchievementDataForLoggedOnUserAsync(
				version,
				function (result) {
					version = result.Version;
					console.log(result);
					proc(version);
				},
				function (error) {
					var shouldShowError = (error.errorType !== 'TimeoutException')
					window.setTimeout(function () {
						if (shouldShowError)
							SC.dialog.hideModalDialog();

						proc(version);
					}, 10000);
				}
			)
		}
	};

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		if (pendingRequest) {
			pendingRequest.abort();
			pendingRequest = null;
		}
	});

	proc(version);
});

SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
	switch (eventArgs.area) {
		case 'ExtrasPopoutPanel':
			eventArgs.buttonDefinitions.push({ commandName: 'viewAchievements', text: SC.res['Achievements.AchievementText'], className: 'AlwaysOverflow' });
			break;
	}
});