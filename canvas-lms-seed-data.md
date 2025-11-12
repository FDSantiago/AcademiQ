# Canvas LMS Seed Data and Migrations

## Overview
This document provides comprehensive seed data and migration notes for a Canvas LMS-like system built with Laravel. It includes realistic data for institutions, users, courses, modules, assignments, submissions, and end-to-end workflow demonstrations.

## Database Migrations

### New Models Required

#### 1. Pages Table
```php
Schema::create('pages', function (Blueprint $table) {
    $table->id();
    $table->foreignId('course_id')->constrained()->onDelete('cascade');
    $table->string('title');
    $table->longText('body')->nullable();
    $table->boolean('published')->default(false);
    $table->integer('order')->default(0);
    $table->timestamps();
});
```

#### 2. Outcomes Table
```php
Schema::create('outcomes', function (Blueprint $table) {
    $table->id();
    $table->foreignId('course_id')->constrained()->onDelete('cascade');
    $table->string('title');
    $table->text('description')->nullable();
    $table->enum('mastery_level', ['beginner', 'intermediate', 'advanced', 'expert'])->default('beginner');
    $table->decimal('points_possible', 5, 2)->default(0);
    $table->timestamps();
});
```

#### 3. Calendar Events Table
```php
Schema::create('calendar_events', function (Blueprint $table) {
    $table->id();
    $table->foreignId('course_id')->constrained()->onDelete('cascade');
    $table->string('title');
    $table->text('description')->nullable();
    $table->dateTime('start_date');
    $table->dateTime('end_date');
    $table->enum('event_type', ['assignment', 'quiz', 'discussion', 'announcement', 'other'])->default('other');
    $table->timestamps();
});
```

#### 4. Messages Table
```php
Schema::create('messages', function (Blueprint $table) {
    $table->id();
    $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
    $table->foreignId('recipient_id')->constrained('users')->onDelete('cascade');
    $table->string('subject');
    $table->text('body');
    $table->boolean('read')->default(false);
    $table->timestamps();
});
```

#### 5. External Tools Table
```php
Schema::create('external_tools', function (Blueprint $table) {
    $table->id();
    $table->foreignId('course_id')->constrained()->onDelete('cascade');
    $table->string('name');
    $table->text('description')->nullable();
    $table->string('launch_url');
    $table->string('consumer_key');
    $table->string('shared_secret');
    $table->boolean('enabled')->default(true);
    $table->timestamps();
});
```

#### 6. Files Table
```php
Schema::create('files', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('original_name');
    $table->string('path');
    $table->string('mime_type');
    $table->integer('size');
    $table->morphs('fileable'); // Polymorphic relationship
    $table->foreignId('uploaded_by')->constrained('users')->onDelete('cascade');
    $table->timestamps();
});
```

### Polymorphic Relations for Modules

Update the `module_resources` table to support polymorphic relationships:

```php
Schema::table('module_resources', function (Blueprint $table) {
    $table->string('resourceable_type')->nullable()->after('file_path');
    $table->unsignedBigInteger('resourceable_id')->nullable()->after('resourceable_type');
    $table->index(['resourceable_type', 'resourceable_id']);
});
```

## Database Seeders

### InstitutionSeeder.php
```php
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class InstitutionSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('institutions')->insert([
            [
                'name' => 'University of Technology',
                'domain' => 'utech.edu',
                'address' => '123 Tech Street, Silicon Valley, CA 94000',
                'phone' => '+1-555-0123',
                'email' => 'admin@utech.edu',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);
    }
}
```

### UserSeeder.php
```php
<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        // Admin User
        $admin = User::firstOrCreate(
            ['email' => 'admin@utech.edu'],
            [
                'name' => 'System Administrator',
                'password' => Hash::make('password'),
                'email_verified_at' => now(),
            ]
        );
        $admin->roles()->sync([1]); // admin role

        // Instructor
        $instructor = User::firstOrCreate(
            ['email' => 'john.doe@utech.edu'],
            [
                'name' => 'Dr. John Doe',
                'password' => Hash::make('password'),
                'email_verified_at' => now(),
            ]
        );
        $instructor->roles()->sync([2]); // instructor role

        // Students
        $students = [
            ['name' => 'Alice Johnson', 'email' => 'alice.johnson@utech.edu'],
            ['name' => 'Bob Smith', 'email' => 'bob.smith@utech.edu'],
            ['name' => 'Carol Williams', 'email' => 'carol.williams@utech.edu'],
            ['name' => 'David Brown', 'email' => 'david.brown@utech.edu'],
            ['name' => 'Emma Davis', 'email' => 'emma.davis@utech.edu'],
        ];

        foreach ($students as $studentData) {
            $student = User::firstOrCreate(
                ['email' => $studentData['email']],
                [
                    'name' => $studentData['name'],
                    'password' => Hash::make('password'),
                    'email_verified_at' => now(),
                ]
            );
            $student->roles()->sync([3]); // student role
        }
    }
}
```

### CourseSeeder.php
```php
<?php

namespace Database\Seeders;

use App\Models\Course;
use App\Models\CourseModule;
use App\Models\Assignment;
use App\Models\Announcement;
use Illuminate\Database\Seeder;

class CourseSeeder extends Seeder
{
    public function run(): void
    {
        $instructor = \App\Models\User::where('email', 'john.doe@utech.edu')->first();

        // Create Computer Science 101
        $course = Course::create([
            'instructor_id' => $instructor->id,
            'title' => 'Introduction to Computer Science',
            'description' => 'A comprehensive introduction to computer science fundamentals including programming, algorithms, and data structures.',
            'course_code' => 'CS101',
            'status' => 'active',
        ]);

        // Create modules
        $modules = [
            [
                'title' => 'Getting Started with Programming',
                'description' => 'Introduction to programming concepts and Python basics',
                'order' => 1,
            ],
            [
                'title' => 'Data Structures and Algorithms',
                'description' => 'Understanding fundamental data structures and algorithm design',
                'order' => 2,
            ],
            [
                'title' => 'Object-Oriented Programming',
                'description' => 'Principles of OOP and advanced programming techniques',
                'order' => 3,
            ],
        ];

        foreach ($modules as $moduleData) {
            CourseModule::create(array_merge($moduleData, ['course_id' => $course->id]));
        }

        // Create assignments
        $assignments = [
            [
                'title' => 'Hello World Program',
                'description' => 'Write your first Python program that prints "Hello, World!"',
                'due_date' => now()->addDays(7),
                'points' => 10,
                'submission_type' => 'online_text_entry',
            ],
            [
                'title' => 'Algorithm Analysis',
                'description' => 'Analyze the time and space complexity of common algorithms',
                'due_date' => now()->addDays(14),
                'points' => 25,
                'submission_type' => 'online_text_entry',
            ],
            [
                'title' => 'OOP Project',
                'description' => 'Create a simple object-oriented program demonstrating inheritance and polymorphism',
                'due_date' => now()->addDays(21),
                'points' => 50,
                'submission_type' => 'online_upload',
            ],
        ];

        foreach ($assignments as $assignmentData) {
            Assignment::create(array_merge($assignmentData, ['course_id' => $course->id]));
        }

        // Create welcome announcement
        Announcement::create([
            'course_id' => $course->id,
            'title' => 'Welcome to CS101!',
            'content' => 'Welcome to Introduction to Computer Science! This course will take you through the fundamentals of programming and computer science concepts. Please review the syllabus and course modules.',
            'published' => true,
        ]);

        // Enroll students
        $students = \App\Models\User::whereHas('roles', function($q) {
            $q->where('name', 'student');
        })->get();

        foreach ($students as $student) {
            $course->students()->attach($student->id, [
                'status' => 'active',
                'enrolled_at' => now(),
            ]);
        }
    }
}
```

### SubmissionSeeder.php
```php
<?php

namespace Database\Seeders;

use App\Models\AssignmentSubmission;
use App\Models\Assignment;
use App\Models\User;
use Illuminate\Database\Seeder;

class SubmissionSeeder extends Seeder
{
    public function run(): void
    {
        $assignments = Assignment::all();
        $students = User::whereHas('roles', function($q) {
            $q->where('name', 'student');
        })->get();

        foreach ($assignments as $assignment) {
            foreach ($students as $student) {
                // Simulate different submission statuses
                $statuses = ['submitted', 'graded', 'returned'];
                $status = $statuses[array_rand($statuses)];

                AssignmentSubmission::create([
                    'assignment_id' => $assignment->id,
                    'user_id' => $student->id,
                    'content' => $this->generateSampleSubmission($assignment->title),
                    'status' => $status,
                ]);
            }
        }
    }

    private function generateSampleSubmission($assignmentTitle)
    {
        $submissions = [
            'Hello World Program' => "print('Hello, World!')",
            'Algorithm Analysis' => "The bubble sort algorithm has O(n²) time complexity in the worst case because it uses nested loops to compare and swap elements.",
            'OOP Project' => "class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        pass

class Dog(Animal):
    def speak(self):
        return 'Woof!'

class Cat(Animal):
    def speak(self):
        return 'Meow!'",
        ];

        return $submissions[$assignmentTitle] ?? 'Sample submission content.';
    }
}
```

### OutcomeSeeder.php
```php
<?php

namespace Database\Seeders;

use App\Models\Outcome;
use App\Models\Course;
use Illuminate\Database\Seeder;

class OutcomeSeeder extends Seeder
{
    public function run(): void
    {
        $course = Course::where('course_code', 'CS101')->first();

        if ($course) {
            $outcomes = [
                [
                    'title' => 'Programming Fundamentals',
                    'description' => 'Students will demonstrate proficiency in basic programming concepts including variables, loops, and functions.',
                    'mastery_level' => 'intermediate',
                    'points_possible' => 100,
                ],
                [
                    'title' => 'Algorithm Design',
                    'description' => 'Students will be able to design and analyze algorithms for common computational problems.',
                    'mastery_level' => 'advanced',
                    'points_possible' => 100,
                ],
                [
                    'title' => 'Object-Oriented Programming',
                    'description' => 'Students will understand and apply object-oriented programming principles.',
                    'mastery_level' => 'intermediate',
                    'points_possible' => 100,
                ],
            ];

            foreach ($outcomes as $outcomeData) {
                Outcome::create(array_merge($outcomeData, ['course_id' => $course->id]));
            }
        }
    }
}
```

## End-to-End Flow Demonstrations

### Student Submission Flow
1. Student logs in and navigates to course
2. Views available assignments in the assignments section
3. Clicks on an assignment to view details and requirements
4. Submits work through the appropriate submission method (text entry or file upload)
5. Receives confirmation of submission

### Instructor Grading Flow
1. Instructor logs in and navigates to course
2. Goes to assignments section and selects an assignment
3. Views all student submissions
4. Reviews submission content or downloads attached files
5. Enters grade and feedback
6. Marks submission as graded

### Module Navigation Flow
1. Student accesses course modules
2. Views module content in order
3. Completes readings and activities
4. Progress is tracked automatically
5. Prerequisites are enforced where applicable

### Announcement Creation Flow
1. Instructor creates new announcement
2. Sets title and content
3. Chooses publication options
4. Announcement appears in course feed
5. Students receive notifications (if implemented)

## Testing Guidelines

### Unit Tests
- Test model relationships and data integrity
- Validate business logic in services
- Test API endpoints for CRUD operations

### Feature Tests
- Test complete user workflows (enrollment, submission, grading)
- Validate authorization and permissions
- Test file upload and processing

### Performance Tests
- Load test with multiple concurrent users
- Test database queries with large datasets
- Monitor memory usage during bulk operations

### Sample Test Commands
```bash
# Run all tests
php artisan test

# Run specific test suite
php artisan test --testsuite=Feature

# Run tests with coverage
php artisan test --coverage
```

## Performance Considerations

### Database Optimization
1. **Indexing**: Add indexes on frequently queried columns (user_id, course_id, assignment_id)
2. **Eager Loading**: Use `with()` to prevent N+1 queries in relationships
3. **Pagination**: Implement pagination for large result sets
4. **Caching**: Cache frequently accessed data (course info, user roles)

### Application Performance
1. **File Storage**: Use cloud storage (S3) for uploaded files
2. **Queue Processing**: Process heavy operations asynchronously (grade calculations, notifications)
3. **Database Connections**: Monitor and optimize connection pooling
4. **Memory Management**: Stream large files instead of loading into memory

### Monitoring
1. **Query Performance**: Log slow queries (>100ms)
2. **Error Tracking**: Implement error monitoring and alerting
3. **User Metrics**: Track page load times and user interactions
4. **Resource Usage**: Monitor CPU, memory, and disk usage

## Migration Order
1. Run existing migrations
2. Create new model migrations in this order:
   - pages
   - outcomes
   - calendar_events
   - messages
   - external_tools
   - files
3. Update module_resources for polymorphism
4. Run seeders in this order:
   - InstitutionSeeder
   - UserSeeder
   - CourseSeeder
   - SubmissionSeeder
   - OutcomeSeeder

## Notes
- All passwords are set to 'password' for testing purposes
- Sample data represents a realistic educational scenario
- Polymorphic relationships allow flexible content association
- Consider implementing soft deletes for audit trails
- Add proper validation rules in form requests
- Implement proper error handling and logging