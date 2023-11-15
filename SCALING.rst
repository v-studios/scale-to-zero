=========
 Scaling
=========

Aurora PostgreSQL serverless v1
===============================

Updating with 13.9 loooking good so far, config page shows::

  Autoscaling timeout
  5 minutes
  Pause compute capacity after consecutive minutes of inactivity
  5 minutes


DB:

* November 15, 2023, 18:18 The DB cluster is being paused.
* November 15, 2023, 18:19 The DB cluster is paused.
* November 15, 2023, 18:41 The DB cluster is being resumed.
* November 15, 2023, 18:42 The DB cluster is resumed.
* November 15, 2023, 18:48 Scaling DB cluster from 2 capacity units to
                           4 capacity units for this reason: Autoscaling.
* November 15, 2023, 18:48 The DB cluster has scaled from 2 capacity
                           units to 4 capacity units.

App Runner
==========

The `"Auto scaling" section
<https://eu-west-3.console.aws.amazon.com/apprunner/home?region=eu-west-3#/services/dashboard?service_arn=arn%3Aaws%3Aapprunner%3Aeu-west-3%3A150806394439%3Aservice%2Fscale0-dev%2Fafbea56dc8c14dddbd81122e1a0e9781&active_tab=configuration>`_
of the App Runner > Services > scale0-dev > Connfiguration shows:

  Name:              DefaultConfiguration
  Revision number:   1
  Concurrency:     100
  Minimum size:      1
  Maximum size:     25

So it should be able to handle 100 concurrent requests before scaling
up, to a maximum of 25 instances. This should be fine.

We could create an `auto scaling configuration
<https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-apprunner-autoscalingconfiguration.html>`_
and reference it by ARN in the App Runner config but it's not
necessary for this test now.

If we can run a load tester against it that submits over 100
concurrent requests, we should see it scale.

Load Testing
------------

I can use the simple `hey <https://github.com/rakyll/hey>`_ too to load test. The following runs for 1 minute, with a concurrency of 150:

  hey -c 150 -z 1m https://ykcgyztfmf.eu-west-3.awsapprunner.com/

