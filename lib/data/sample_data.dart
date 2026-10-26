import '../models/book.dart';
import '../models/member.dart';

const sampleBooks = [
  Book(
    id: 'b1',
    title: 'Clean Code',
    author: 'Robert C. Martin',
    totalCopies: 2,
  ),
  Book(
    id: 'b2',
    title: 'The Pragmatic Programmer',
    author: 'Hunt & Thomas',
    totalCopies: 1,
  ),
  Book(id: 'b3', title: 'Refactoring', author: 'Martin Fowler', totalCopies: 3),
  Book(
    id: 'b4',
    title: 'Domain-Driven Design',
    author: 'Eric Evans',
    totalCopies: 1,
  ),
  Book(
    id: 'b5',
    title: 'Test-Driven Development',
    author: 'Kent Beck',
    totalCopies: 2,
  ),
];

const sampleMembers = [
  Member(id: 'm1', name: 'Sara'),
  Member(id: 'm2', name: 'Omar'),
];
