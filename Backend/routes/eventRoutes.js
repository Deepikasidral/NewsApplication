// routes/eventRoutes.js (recommended filename)
const express = require('express');
const router = express.Router();
const Event = require('../models/Event');

// GET all events
// This will be /api/events (not /api/api/events)
router.get('/', async (req, res) => { // Changed from '/api/events' to '/'
  try {
    const events = await Event.find().sort({ date: 1 });
    res.json({
      success: true,
      events: events
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching events',
      error: error.message
    });
  }
});

// GET event by ID
router.get('/:id', async (req, res) => { // Changed from '/api/events/:id' to '/:id'
  try {
    const event = await Event.findById(req.params.id);
    if (!event) {
      return res.status(404).json({
        success: false,
        message: 'Event not found'
      });
    }
    res.json({
      success: true,
      event: event
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching event',
      error: error.message
    });
  }
});

// POST new event
router.post('/', async (req, res) => { // Changed from '/api/events' to '/'
  try {
    const event = new Event(req.body);
    await event.save();
    res.status(201).json({
      success: true,
      message: 'Event created successfully',
      event: event
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      message: 'Error creating event',
      error: error.message
    });
  }
});

module.exports = router;