# Offline sample validation rule

This rule belongs to the branch task manual.

Before accepting a new task, the task party must check whether the repository already contains sample data that can reproduce the task.

If usable sample data exists, it must be used for at least one validation run or comparison.

If sample data exists but cannot be used, the task party must record:

- searched paths
- matching files
- why the files appear relevant
- why they cannot be used
- proposed alternative verification
- supervisor decision status

If no relevant sample data exists, record:

- sample_data_available: false
- searched paths or patterns

The supervisor decides whether a reason for not using repository sample data is acceptable.
