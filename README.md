ISSUES:
	Updating the achievement definitions will be hard after the Extension is released. It's gonna take code to add them. That can get hairy... Maybe we can just add a web method to do it or something so that we can call it at any time
	The extension doesn't use the security context or anything. Just gets user data based on the username. Assuming usernames are unique this should be fine. But anyone is really able to get or update anyone elses achievements. The key this in the triggers mitigates this
	Gotta put triggers into the cs file
	Gotta figure out how to always get the actual user name instead of the profile name