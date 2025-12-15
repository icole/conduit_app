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