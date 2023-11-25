======================
Quesionts and Cautions
======================

Aurora Serverless v1 Scaling
============================

The `Best practices blog for Aurora Serverless v1
<https://aws.amazon.com/blogs/database/best-practices-for-working-with-amazon-aurora-serverless/>`_
says:

  you should be mindful of a few things, such as connection management
  and cold starts.
  ...
  Serverless applications can open a large number of database
  connections or frequently open and close connections. This can have
  a negative impact on the database and lead to slower performance.
  ...
  If there is a sudden spike in requests, you can overwhelm the
  database. Aurora Serverless v1 might not be able to find a scaling
  point and scale quickly enough

We'd like to find a way to speed scaling up on high load, though the
``hey`` load tester is not realiztic. We'd like it to scale so we
don't run out of database connections. This doc discusses `How Aurora
Serverless v1 works
<https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v1.how-it-works.html#aurora-serverless.how-it-works.auto-scaling>`_


Why not v2?
===========

So why not use Aurora Serverless v2, insetad of v1? We're using v1
because it scales to 0 ACU, so costs nothing but the disk our data
needs. Aurora Serverless v2 scales down to 0.5 ACU, which means it
costs money for CPU even if nothing is using it -- exactly what we are
trying to avoid here.

But v2 scales up much faster than v1. This `Serverless Guru tip
<https://www.serverlessguru.com/tips/amazon-aurora-serverless-v1-vs-v2>`_
provides a good comparison; briefly:

* Aurora v1 scales up in seconds, v2 in milliseconds
* v1 can take 15 minutes to scale down, v2 in under a minute
* v2 scales much more finely, in 0.5 ACU increments.

The `Performance and scaling doc
<https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.setting-capacity.html>`_
goes into detail on this.
