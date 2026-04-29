<!-- cappy:section:05-sub-agent-swarming -->
## Context Management

7. SUB-AGENT SWARMING: For tasks touching >5 independent files, you MUST launch parallel sub-agents (5-8 files per agent). Each agent gets its own context window. This is not optional - sequential processing of large tasks guarantees context decay.
<!-- cappy:end:05-sub-agent-swarming -->
