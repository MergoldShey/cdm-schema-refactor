import LogRocket from 'logrocket';

// Initialize the session link
LogRocket.init('mnxehd/cdm-schema-refactor');

// Optional: Identify the session for easier tracking in your dashboard
LogRocket.identify('shiphrah_test_user', {
  name: 'Chimeremma Shiphrah',
  role: 'Clinical Data Engineer',
});

// A simple function to trigger a log event
console.log("LogRocket session started: Monitoring clinical_data_infrastructure");
LogRocket.log("The system has successfully initialized the tracking layer.");
