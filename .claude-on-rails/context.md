# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Domain Context: Cohousing Community

ConduitApp is a management platform for a **cohousing community**. Cohousing is a form of collaborative housing where residents live in private homes clustered around shared spaces, with a strong emphasis on community life.

### Key Cohousing Characteristics

- **Private + Shared**: Each household has a private residence with full amenities, but the community shares common spaces (common house, gardens, laundry, workshops)
- **Common House**: A central building with shared kitchen, dining area, sitting room, children's playroom, guest rooms, and other amenities
- **Shared Meals**: A defining feature - communities typically share 2-3 meals per week in the common house. Members rotate cooking duties
- **Collaborative Decision-Making**: Residents work together on decisions affecting the community, often using consensus-based processes
- **Shared Resources & Responsibilities**: Community chores, childcare, tool-sharing, and resource pooling
- **Intentional Community**: Designed to foster meaningful social connections while respecting privacy

### Community Management Features

This application helps manage:
- **Community Meals**: Scheduling, cook rotation, RSVP tracking, and guest management
- **Chores & Work Parties**: Tracking shared responsibilities and community maintenance
- **Discussions & Decisions**: Facilitating community dialogue and recording decisions
- **Calendar & Events**: Community gatherings, meetings, and social events
- **Documents**: Meeting minutes, policies, and shared resources
- **Communication**: Posts, comments, and notifications

When building features, consider:
- The balance between community engagement and respecting individual privacy
- Making participation easy but not mandatory
- Supporting diverse household sizes and schedules
- Facilitating volunteer coordination and fair distribution of responsibilities

## Project Information

- **Rails Version**: 8.0.2
- **Ruby Version**: 3.4.4
- **Project Type**: Full-stack Rails
- **Test Framework**: Minitest
- **Turbo/Stimulus**: Enabled

## Swarm Configuration

The claude-swarm.yml file defines specialized agents for different aspects of Rails development:

- Each agent has specific expertise and works in designated directories
- Agents collaborate to implement features across all layers
- The architect agent coordinates the team

## Development Guidelines

When working on this project:

- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries

## Test-Driven Development (TDD)

**IMPORTANT: This project strictly follows TDD. Always write tests BEFORE implementation code.**

For ALL changes (new features, bug fixes, refactors):

1. **Write a failing test first** - Before writing ANY implementation code, create a test that describes the expected behavior. For bug fixes, write a test that reproduces the bug.
2. **Run the test to confirm it fails** - Verify the test fails for the right reason (not due to syntax errors)
3. **Implement the minimum code to pass** - Write just enough code to make the test pass
4. **Refactor if needed** - Clean up the code while keeping tests green
5. **Run all tests** - Ensure no regressions were introduced

**Do not skip step 1.** Even for "obvious" fixes, the test-first approach ensures the bug is properly understood and prevents regressions.

### Test Types

- **System tests** (`test/system/`) - For user-facing behavior and UI interactions
- **Model tests** (`test/models/`) - For business logic and validations
- **Controller tests** (`test/controllers/`) - For request/response handling
- **Integration tests** (`test/integration/`) - For multi-step workflows

### Running Tests

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/system/meals_test.rb

# Run specific test by line number
bin/rails test test/system/meals_test.rb:129
```

### Pre-Commit Checklist

Before committing, always run:
1. `bin/rubocop` - Linting
2. `bin/rails test` - All tests
3. `bin/brakeman --no-pager` - Security scan