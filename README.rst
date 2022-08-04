======================
 Wagtail on AppRunner
======================

AppRunner is ideally suited for running pure HTTP apps that don't need
features Fargate provides. The config is much simpler, and it
autoscales based on demand and includes its own ALB. It can now access
things in a VPC, so we can have our app talk to an RDS (or Aurora
serverless) DB. Both can scale to zero to save money on sites that
aren't used 24x7.

We want to deploy Wagtail CMS with a PostgreSQL DB. Start with 24x7
RDS to get the VPC worked out, then try scale-to-zero Aurora.

See:

* Excellent blog post comparing simplicity and cost: `Fargate vs. App
  Runner <https://cloudonaut.io/fargate-vs-apprunner/>`_
* Live Coding video: `Migrating from ECS and Fargate to AWS App Runner
  <https://www.youtube.com/watch?v=ABvx7radhw4>`_
* AWS AppRunner `FAQs <https://aws.amazon.com/apprunner/faqs/>`_

VPC for RDS
===========

We'll need a VPC for RDS and it has to export its subnets and security
groups so we can reference them in the AppRunner config. We do that
with ``vpc.yaml``.
